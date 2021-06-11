module Cuboid
module Support::Database

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class CategorizedQueue < Base

    # Default {#max_buffer_size}.
    DEFAULT_MAX_BUFFER_SIZE = 100

    # @return   [Integer]
    #   How many entries to keep in memory before starting to off-load to disk.
    attr_accessor :max_buffer_size

    attr_accessor :prefer

    # @see Cuboid::Database::Base#initialize
    def initialize( options = {}, &block )
        super( options )

        @prefer = block
        @max_buffer_size = options[:max_buffer_size] || DEFAULT_MAX_BUFFER_SIZE

        @categories ||= {}
        @waiting = []
        @mutex   = Mutex.new

        @buffer_size = 0
        @disk_size   = 0
    end

    # @note Defaults to {DEFAULT_MAX_BUFFER_SIZE}.
    #
    # @return   [Integer]
    #   How many entries to keep in memory before starting to off-load to disk.
    def max_buffer_size
        @max_buffer_size
    end

    def categories
        @categories.keys
    end

    def data_for( category )
        @categories[category.to_s] ||= {
            disk:   [],
            buffer: []
        }
    end

    def insert_to_disk( category, path )
        data_for( category )[:disk] << path
        @disk_size += 1
    end

    # @param    [Object]    obj
    #   Object to add to the queue.
    #   Must respond to #category.
    def <<( obj )
        fail ArgumentError, 'Missing #prefer block.' if !@prefer

        if !obj.respond_to?( :category )
            fail ArgumentError, "#{obj.class} does not respond to #category."
        end

        synchronize do
            data = data_for( obj.category )

            if data[:buffer].size < max_buffer_size
                @buffer_size += 1
                data[:buffer] << obj
            else
                @disk_size += 1
                data[:disk] << dump( obj )
            end

            begin
                t = @waiting.shift
                t.wakeup if t
            rescue ThreadError
                retry
            end
        end
    end
    alias :push :<<
    alias :enq :<<

    # @return   [Object]
    #   Removes an object from the queue and returns it.
    def pop( non_block = false )
        fail ArgumentError, 'Missing #prefer block.' if !@prefer

        synchronize do
            loop do
                if internal_empty?
                    raise ThreadError, 'queue empty' if non_block
                    @waiting.push Thread.current
                    @mutex.sleep
                else
                    # Get preferred category, hopefully there'll be some data
                    # for it.
                    category = @prefer.call( @categories.keys )

                    # Get all other available categories just in case the
                    # preferred one is empty.
                    categories = @categories.keys
                    categories.delete category

                    data = nil
                    # Check if our category has data and pick another if not.
                    loop do
                        data = data_for( category )
                        if data[:buffer].any? || data[:disk].any?
                            break
                        end

                        category = categories.pop
                    end

                    if data[:buffer].any?
                        @buffer_size -= 1
                        return data[:buffer].shift
                    end

                    @disk_size -= 1
                    return load_and_delete_file( data[:disk].shift )
                end
            end
        end
    end
    alias :deq :pop
    alias :shift :pop

    # @return   [Integer]
    #   Size of the queue, the number of objects it currently holds.
    def size
        buffer_size + disk_size
    end
    alias :length :size

    def free_buffer_size
        max_buffer_size - buffer_size
    end

    def buffer_size
        @buffer_size
    end

    def disk_size
        @disk_size
    end

    # @return   [Bool]
    #   `true` if the queue if empty, `false` otherwise.
    def empty?
        synchronize do
            internal_empty?
        end
    end

    # Removes all objects from the queue.
    def clear
        synchronize do
            @categories.values.each do |data|
                data[:buffer].clear

                while !data[:disk].empty?
                    path = data[:disk].pop
                    next if !path
                    delete_file path
                end
            end

            @buffer_size = 0
            @disk_size   = 0
        end
    end

    def num_waiting
        @waiting.size
    end

    private

    def internal_empty?
        @buffer_size == 0 && @disk_size == 0
    end

    def synchronize( &block )
        @mutex.synchronize( &block )
    end

end

end
end
