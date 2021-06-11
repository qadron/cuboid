module Cuboid

class System
class Slots

    def initialize( system )
        @system = system
        @pids   = Set.new
    end

    def reset
        @pids.clear
    end

    def use( pid )
        @pids << pid
        pid
    end

    # @return   [Integer]
    #   Amount of new scans that can be safely run in parallel, currently.
    #   User option will override decision based on system resources.
    def available
        # Manual mode, user gave us a value.
        if (max_slots = Options.system.max_slots)
            max_slots - used

        # Auto-mode, pick the safest restriction, RAM vs CPU.
        else
            available_auto
        end
    end

    # @return   [Integer]
    #   Amount of new scans that can be safely run in parallel, currently.
    #   The decision is based on the available resources alone.
    def available_auto
        [ available_in_memory, available_in_cpu, available_in_disk ].min
    end

    # @return   [Integer]
    #   Amount of instances that are currently alive.
    def used
        @pids.select! { |pid| Processes::Manager.alive? pid }
        @pids.size
    end

    # @return   [Integer]
    #   Amount of scans that can be safely run in parallel, in total.
    def total
        used + available
    end

    # @return   [Integer]
    #   Amount of scans we can fit into the available memory.
    #
    #   Works based on slots, available memory isn't currently available OS
    #   memory but memory that is unallocated.
    def available_in_memory
        return Float::INFINITY if memory_size == 0
        (unallocated_memory / memory_size).to_i
    end

    # @return   [Integer]
    #   Amount of CPU cores that are available.
    #
    #   Well, they may not be really available, other stuff on the machine could
    #   be using them to a considerable extent, but we can only do so much.
    def available_in_cpu
        @system.cpu_count - used
    end

    # @return   [Integer]
    #   Amount of scans we can fit into the available disk space.
    #
    #   Works based on slots, available space isn't currently available OS
    #   disk space but space that is unallocated.
    def available_in_disk
        return Float::INFINITY if disk_space == 0
        (unallocated_disk_space / disk_space).to_i
    end

    # @param    [Integer]   pid
    #
    # @return   [Integer]
    #   Remaining memory for the scan, in bytes.
    def remaining_memory_for( pid )
        [memory_size - @system.memory_for_process_group( pid ), 0].max
    end

    # @return   [Integer]
    #   Amount of memory (in bytes) available for future scans.
    def unallocated_memory
        # Available memory right now.
        available_mem = @system.memory_free

        # Remove allocated memory to figure out how much we can really spare.
        @pids.each do |pid|
            # Mark the remaining allocated memory as unavailable.
            available_mem -= remaining_memory_for( pid )
        end

        available_mem
    end

    # @param    [Integer]   pid
    #
    # @return   [Integer]
    #   Remaining disk space for the scan, in bytes.
    def remaining_disk_space_for( pid )
        [disk_space - @system.disk_space_for_process( pid ), 0].max
    end

    # @return   [Integer]
    #   Amount of disk space (in bytes) available for future scans.
    def unallocated_disk_space
        # Available space right now.
        available_space = @system.disk_space_free

        # Remove allocated space to figure out how much we can really spare.
        @pids.each do |pid|
            # Mark the remaining allocated space as unavailable.
            available_space -= remaining_disk_space_for( pid )
        end

        available_space
    end

    def disk_space
        return 0 if !Cuboid::Application.application
        Cuboid::Application.application.max_disk.to_i
    end

    # @return   [Fixnum]
    #   Amount of memory (in bytes) to allocate to each scan.
    def memory_size
        return 0 if !Cuboid::Application.application
        Cuboid::Application.application.max_memory.to_i
    end

end
end
end
