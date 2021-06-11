module Cuboid
module Support::Cache

# Base cache implementation -- stores, retrieves and removes entries.
#
# The cache will be pruned (call {#prune}) upon storage operations, removing
# old entries to make room for new ones.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
# @abstract
class Base
    include Support::Mixins::Profiler

    # @return    [Integer]
    #   Maximum cache size.
    attr_reader :max_size

    # @param    [Hash]  options
    # @option   options [Integer, nil]    :size
    #   Maximum size of the cache (must be > 0, `nil` means unlimited).
    #   Once the size of the cache is about to exceed `max_size`, the pruning
    #   phase will be initiated.
    # # @option   options [true, false]    :freeze    (true)
    #   Whether or not to freeze stored items.
    def initialize( options = {} )
        super()

        @options      = options
        @freeze       = @options[:freeze].nil? ? true : @options[:freeze]
        self.max_size = @options[:size]

        @cache    = {}
        @hits     = 0
        @misses   = 0
        @prunings = 0
    end

    def statistics
        lookups = @hits + @misses

        {
            lookups:    lookups,
            hits:       @hits,
            hit_ratio:  @hits   == 0 ? 0.0 : @hits   / Float( lookups ),
            misses:     @misses,
            miss_ratio: @misses == 0 ? 0.0 : @misses / Float( lookups ),
            prunings:   @prunings,
            size:       size,
            max_size:   max_size
        }
    end

    def max_size=( max )
        @max_size = if !max
            nil
        else
            fail( 'Maximum size must be greater than 0.' ) if max <= 0
            max
        end
    end

    # @return   [Bool]
    #   `true` is there is no size limit, `false` otherwise
    def uncapped?
        !capped?
    end

    # @return   [Bool]
    #   `true` is there is a size limit, `false`` otherwise
    def capped?
        !!max_size
    end

    # Uncaps the cache {#max_size} limit
    def uncap
        @max_size = nil
    end

    # @return   [Integer]
    #   Number of entries in the cache.
    def size
        @cache.size
    end

    # Storage method.
    #
    # @param    [Object]    k
    #   Entry key.
    # @param    [Object]    v
    #   Object to store.
    #
    # @return   [Object]    `v`
    def store( k, v )
        store_with_internal_key( make_key( k ), v )
    end

    # @see #store
    def []=( k, v )
        store( k, v )
    end

    # Retrieving method.
    #
    # @param    [Object]    k
    #   Entry key.
    #
    # @return   [Object, nil]
    #   Value for key `k`, `nil` if there is no key `k`.
    def []( k )
        get_with_internal_key( make_key( k ) )
    end

    # @note If key `k` exists, its corresponding value will be returned.
    #   If not, the return value of `block` will be assigned to key `k` and that
    #   value will be returned.
    #
    # @param    [Object]    k
    #   Entry key.
    #
    # @return   [Object]
    #   Value for key `k` or `block.call` if key `k` does not exist.
    def fetch( k, &block )
        k = make_key( k )

        if @cache.include?( k )
            get_with_internal_key( k )
        else
            @misses += 1
            store_with_internal_key( k, profile_proc( &block ) )
        end
    end

    # @return   [Bool]
    #   `true` if cache includes an entry for key `k`, false otherwise.
    def include?( k )
        @cache.include?( make_key( k ) )
    end

    # @return   [Bool]
    #   `true` if cache is empty, false otherwise.
    def empty?
        @cache.empty?
    end

    # @return   [Bool]
    #   `true` if cache is not empty, `false` otherwise.
    def any?
        !empty?
    end

    # Removes entry with key `k` from the cache.
    #
    # @param    [Object]    k
    #   Key.
    #
    # @return   [Object, nil]
    #   Value for key `k`, `nil` if there is no key `k`.
    def delete( k )
        @cache.delete( make_key( k ) )
    end

    # Clears/empties the cache.
    def clear
        @cache.clear
    end

    def ==( other )
        hash == other.hash
    end

    def hash
        @cache.hash
    end

    def dup
        self.class.new( @options.dup ).tap { |h| h.cache = @cache.dup }
    end

    protected

    def cache=( c )
        @cache = c
    end

    private

    def store_with_internal_key( k, v )
        while capped? && (size > max_size - 1)
            prune
            @prunings += 1
        end

        _store( k, v )
    end

    def _store( k, v )
        @cache[k] = @freeze ? v.freeze : v
    end

    def get_with_internal_key( k )
        if (r = @cache[k])
            @hits += 1
        else
            @misses += 1
        end
        r
    end

    def make_key( k )
        k.hash
    end

    def cache
        @cache
    end

    # Called to make room when the cache is about to reach its maximum size.
    #
    # @abstract
    def prune
        fail NotImplementedError
    end

end
end
end
