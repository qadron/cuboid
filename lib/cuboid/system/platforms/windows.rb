module Cuboid

class System
module Platforms

class Windows < Base

    class <<self
        def current?
            Cuboid.windows?
        end
    end

    # @return   [Integer]
    #   Amount of free RAM in bytes.
    def memory_free
        result = wmi.ExecQuery(
            'select AvailableBytes from Win32_PerfFormattedData_PerfOS_Memory'
        )

        memory = nil
        result.each do |e|
            memory = e.availableBytes.to_i
            e.ole_free
        end
        result.ole_free

        memory
    end

    # @param    [Integer]   pgid
    #   Process group ID.
    #
    # @return   [Integer]
    #   Amount of RAM in bytes used by the given GPID.
    def memory_for_process_group( pgid )
        processes = wmi.ExecQuery(
            "select PrivatePageCount from win32_process where ProcessID='#{pgid}' or ParentProcessID='#{pgid}'"
        )

        memory = 0
        processes.each do |process|
            # Not actually pages but bytes, no idea why.
            memory += process.privatePageCount.to_i
            process.ole_free
        end
        processes.ole_free

        memory
    end

    # @return   [Integer]
    #   Amount of free disk in bytes.
    def disk_space_free
        device_id = disk_directory.split( '/' ).first

        drives = wmi.ExecQuery(
            "select FreeSpace from win32_LogicalDisk where DeviceID='#{device_id}'"
        )

        space = nil
        drives.each do |drive|
            space = drive.freeSpace.to_i
            drive.ole_free
        end
        drives.ole_free

        space
    end

    private

    def wmi
        @wmi ||= WIN32OLE.connect( 'winmgmts://' )
    end

end
end
end

end
