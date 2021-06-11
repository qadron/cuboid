module Cuboid
module Support::Filter

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
# @abstract
class Base

    attr_reader :collection

    DEFAULT_OPTIONS = {
        hasher: :hash
    }

    # @param    [Set]  options
    # @option   options [Symbol]    (:hasher)
    #   Method to call on the item to obtain its hash.
    def initialize( options = {} )
        @options = DEFAULT_OPTIONS.merge( options )
        @hasher  = @options[:hasher].to_sym
    end

    # @param    [#persistent_hash] item
    #   Item to insert.
    #
    # @return   [Base]
    #   `self`
    def <<( item )
        @collection << calculate_hash( item )
        self
    end

    # @param    [#persistent_hash] item
    #   Item to check.
    #
    # @return   [Bool]
    def include?( item )
        @collection.include? calculate_hash( item )
    end

    def empty?
        @collection.empty?
    end

    def any?
        !empty?
    end

    def size
        @collection.size
    end

    def clear
        @collection.clear
    end

    def merge( other )
        case other
            when self.class

                @collection.merge other.collection

            when Array

                other.each do |k|
                    fail 'Cannot merge with unhashed entries' if !k.is_a?( Numeric )
                    @collection << k
                end

            else
                fail ArgumentError,
                     "Don't know how to merge with: #{other.class}"
        end

        self
    end

    def ==( other )
        hash == other.hash
    end

    def hash
        @collection.hash
    end

    def dup
        self.class.new( @options.dup ).merge self
    end

    def _dump( _ )
        Marshal.dump( to_rpc_data )
    end

    def self._load( data )
        from_rpc_data Marshal.load( data )
    end

    def collection=( c )
        @collection = c
    end

    private

    def calculate_hash( item )
        item.send @hasher
    end

end

end
end
