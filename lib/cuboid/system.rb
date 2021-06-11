require_relative 'system/slots'

module Cuboid

class System
    include Singleton

    # @return   [Array<Platforms::Base>]
    attr_reader :platforms

    # @return   [Slots]
    attr_reader :slots

    def initialize
        @platforms = []
        @slots     = Slots.new( self )
    end

    # @return   [Float]
    #   System utilization based on slots.
    #
    #   * `0.0` => No utilization.
    #   * `1.0` => Max utilization.
    def utilization
        total_slots = System.slots.total
        return 1.0 if total_slots == 0

        System.slots.used / Float( total_slots )
    end

    # @return   [Bool]
    def max_utilization?
        utilization == 1
    end

    # @return   [Integer]
    #   Amount of free RAM in bytes.
    def memory_free
        platform.memory_free
    end

    # @param    [Integer]   pgid
    #   Process group ID.
    #
    # @return   [Integer]
    #   Amount of RAM in bytes used by the given GPID.
    def memory_for_process_group( pgid )
        platform.memory_for_process_group( pgid )
    end

    # @return   [Integer]
    #   Amount of free disk space in bytes.
    def disk_space_free
        platform.disk_space_free
    end

    # @return   [String
    #   Location for temporary file storage.
    def disk_directory
        platform.disk_directory
    end

    # @param    [Integer]   pid
    #   Process ID.
    #
    # @return   [Integer]
    #   Amount of disk space in bytes used by the given PID.
    def disk_space_for_process( pid )
        platform.disk_space_for_process( pid )
    end

    # @return   [Integer]
    #   Amount of CPU cores.
    def cpu_count
        @cpu_count ||= platform.cpu_count
    end

    # @return   [Platforms::Base]
    def platform
        return @platform if @platform

        platforms.each do |klass|
            next if !klass.current?

            return @platform = klass.new
        end

        raise "Unsupported platform: #{RUBY_PLATFORM}"
    end

    # @private
    def register_platform( platform )
        platforms << platform
    end

    # @private
    def reset
        @cpu_count = nil
        @platform  = nil
    end

    class <<self
        def method_missing( sym, *args, &block )
            if instance.respond_to?( sym )
                instance.send( sym, *args, &block )
            else
                super( sym, *args, &block )
            end
        end

        def respond_to?( *args )
            super || instance.respond_to?( *args )
        end
    end

end
end

require_relative 'system/platforms'
