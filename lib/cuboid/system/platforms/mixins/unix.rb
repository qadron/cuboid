require 'vmstat'

module Cuboid
class System
module Platforms
module Mixins

module Unix

    # @param    [Integer]   pgid
    #   Process group ID.
    #
    # @return   [Integer]
    #   Amount of RAM in bytes used by the given GPID.
    def memory_for_process_group( pgid )
        rss = 0

        _exec( "ps -o rss -g #{pgid}" ).split("\n")[1..-1].each do |rss_string|
            rss += rss_string.to_i
        end

        rss * pagesize
    end

    # @return   [Integer]
    #   Amount of free disk in bytes.
    def disk_space_free
        Vmstat.disk( disk_directory ).available_bytes
    end

    private

    def pagesize
        @pagesize ||= memory.pagesize
    end

    def memory
        Vmstat.memory
    end

end

end
end
end
end
