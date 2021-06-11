module Cuboid

class System
module Platforms

class Base
    class <<self

        # @private
        def inherited( platform )
            System.register_platform platform
        end

        # @return   [Bool]
        #   `true` if it's the current platform, `false` otherwise.
        #
        # @abstract
        def current?
            raise 'Missing implementation'
        end
    end

    # @return   [Integer]
    #   Amount of free RAM in bytes.
    #
    # @abstract
    def memory_free
        raise 'Missing implementation'
    end

    # @param    [Integer]   pgid
    #   Process group ID.
    #
    # @return   [Integer]
    #   Amount of RAM in bytes used by the given GPID.
    #
    # @abstract
    def memory_for_process_group( pgid )
        raise 'Missing implementation'
    end

    # @return   [Integer]
    #   Amount of free disk in bytes.
    #
    # @abstract
    def disk_space_free
        raise 'Missing implementation'
    end

    # @return   [String
    #   Location for temporary file storage.
    def disk_directory
        Options.paths.os_tmpdir
    end

    # @param    [Integer]   pid
    #   Process ID.
    #
    # @return   [Integer]
    #   Amount of disk in bytes used by the given PID.
    def disk_space_for_process( pid )
        Support::Database::Base.disk_space_for( pid )
    end

    # @return   [Integer]
    #   Amount of CPU cores.
    def cpu_count
        Concurrent.processor_count
    end

    # @private
    def _exec( cmd )
        %x(#{cmd})
    end

end

end
end
end

Dir.glob( "#{File.dirname(__FILE__)}/**/*.rb" ).each do |platform|
    require platform
end
