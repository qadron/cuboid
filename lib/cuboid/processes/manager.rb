require 'singleton'
require 'raktr'

module Cuboid
module Processes

# Helper for managing processes.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Manager
    include Singleton

    RUNNER = "#{File.dirname( __FILE__ )}/executables/base.rb"

    # @return   [Array<Integer>] PIDs of all running processes.
    attr_reader :pids

    def initialize
        reset
    end

    def reset
        @pids           = []
        @discard_output = true
    end

    # @param    [Integer]   pid
    #   Adds a PID to the {#pids} and detaches the process.
    #
    # @return   [Integer]   `pid`
    def <<( pid )
        @pids << pid
        Process.detach pid
        pid
    end

    # @param    [Integer]   pid
    #   PID of the process to kill.
    def kill( pid )
        fail 'Cannot kill self.' if pid == Process.pid

        Timeout.timeout 10 do
            while sleep 0.1 do
                begin
                    Process.kill( Cuboid.windows? ? 'KILL' : 'TERM', pid )

                # Either kill was successful or we don't have enough perms or
                # we hit a reused PID for someone else's process, either way,
                # consider the process gone.
                rescue Errno::ESRCH, Errno::EPERM,
                    # Don't kill ourselves.
                    SignalException

                    @pids.delete pid
                    return
                end
            end
        end
    rescue Timeout::Error
    end

    def find( bin )
        find_in_path( bin ) || find_in_applications( bin ) ||
            find_in_program_files( bin )
    end

    def find_in_path( bin )
        @find_in_path ||= {}
        return @find_in_path[bin] if @find_in_path.include?( bin )

        if Cuboid.windows?
            bin = "#{bin}.exe"
        end

        ENV['PATH'].split( File::PATH_SEPARATOR ).each do |path|
            f = File.join( path, bin )
            return @find_in_path[bin] = f if File.exist?( f )
        end

        @find_in_path[bin] = nil
    end

    def find_in_applications( bin )
        return if !Cuboid.mac?

        @find_in_applications ||= {}
        return @find_in_applications[bin] if @find_in_applications.include?( bin )

        paths = ENV['PATH'].split( File::PATH_SEPARATOR ) | [
          '/Applications/'
        ]

        paths.each do |root|
            glob = File.join( "#{root}/*/Contents/MacOS", '**', bin )

            exe = Dir.glob( glob ).find { |f| File.executable?( f ) }
            return @find_in_applications[bin] = exe if exe
        end

        @find_in_applications[bin] = nil
    end

    def find_in_program_files( bin )
        return if !Cuboid.windows?

        @find_in_program_files ||= {}
        return @find_in_program_files[bin] if @find_in_program_files.include?( bin )

        [
            ENV['PROGRAMFILES']      || '\\Program Files',
            ENV['ProgramFiles(x86)'] || '\\Program Files (x86)',
            ENV['ProgramW6432']      || '\\Program Files'
        ].each do |root|
            glob = File.join( root, '**', "#{bin}.exe" )
            glob.tr!( '\\', '/' )

            exe = Dir.glob( glob ).find { |f| File.executable?( f ) }
            return @find_in_program_files[bin] = exe if exe
        end

        @find_in_program_files[bin] = nil
    end

    # @param    [Integer]   pid
    # @return   [Boolean]
    #   `true` if the process is alive, `false` otherwise.
    def alive?( pid )
        # Windows is not big on POSIX so try it its own way if possible.
        if Cuboid.windows?
            begin
                alive = false
                processes = wmi.ExecQuery( "select ProcessId from win32_process where ProcessID='#{pid}'" )
                processes.each do |proc|
                    proc.ole_free
                    alive = true
                end
                processes.ole_free

                return alive
            rescue WIN32OLERuntimeError
            end
        end

        # Try using sys-proctable for more reliable process state checking
        begin
            require 'sys/proctable'
            
            # Check if process exists and is not a zombie
            process_info = Sys::ProcTable.ps(pid: pid)
            if process_info
                # On Linux, check the state field to exclude zombie processes
                # 'Z' = zombie, 'X' = dead
                if process_info.respond_to?(:state)
                    return !['Z', 'X'].include?(process_info.state)
                end
                return true
            end
            return false
        rescue LoadError, StandardError
            # Fallback to signal 0 method if sys-proctable isn't available or fails
            !!(Process.kill( 0, pid ) rescue false)
        end
    end

    # @param    [Array<Integer>]   pids
    #   PIDs of the process to {Cuboid::Processes::Manager#kill}.
    def kill_many( pids )
        pids.each { |pid| kill pid }
    end

    # Kills all {#pids processes}.
    def killall
        kill_many @pids.dup
        @pids.clear
    end

    # Stops the Reactor.
    def kill_reactor
        Raktr.stop
    rescue
        nil
    end

    # Overrides the default setting of discarding process outputs.
    def preserve_output
        @discard_output = false
    end

    def preserve_output?
        !discard_output?
    end

    def discard_output
        @discard_output = true
    end

    def discard_output?
        @discard_output
    end

    # @param    [String]    executable
    #   Name of the executable Ruby script found in {OptionGroups::Paths#executables}
    #   without the '.rb' extension.
    # @param    [Hash]  options
    #   Options to pass to the script -- can be retrieved from `$options`.
    #
    # @return   [Integer]
    #   PID of the process.
    def spawn( executable, options = {} )
        fail ArgumentError, 'Fork not supported.' if options.delete(:fork)

        stdin      = options.delete(:stdin)
        stdout     = options.delete(:stdout)
        stderr     = options.delete(:stderr)
        new_pgroup = options.delete(:new_pgroup)
        daemonize  = options.delete(:daemonize)

        spawn_options = {}

        if new_pgroup
            if Cuboid.windows?
                spawn_options[:new_pgroup] = new_pgroup
            else
                spawn_options[:pgroup] = new_pgroup
            end
        end

        spawn_options[:in]  = stdin  if stdin
        spawn_options[:out] = stdout if stdout
        spawn_options[:err] = stderr if stderr

        options[:ppid]   = Process.pid
        options[:tmpdir] = Options.paths.tmpdir

        cuboid_options = Options.dup.update( options.delete(:options) || {} ).to_h
        encoded_cuboid_options = Base64.strict_encode64( Marshal.dump( cuboid_options ) )

        if executable.is_a? Symbol
            executable = "#{Options.paths.executables}/#{executable}.rb"
        elsif !File.exist?( executable )
            raise ArgumentError, "Executable does not exist: #{executable}"
        end

        encoded_options = Base64.strict_encode64( Marshal.dump( options ) )
        argv            = [executable, encoded_options]


        # It's very, **VERY** important that we use this argument format as
        # it bypasses the OS shell and we can thus count on a 1-to-1 process
        # creation and that the PID we get will be for the actual process.
        pid = Process.spawn(
            {
                'CUBOID_SPAWN_OPTIONS' => encoded_cuboid_options
            },
            RbConfig.ruby,
            RUNNER,
            *(argv + [spawn_options])
        )

        self << pid

        if !daemonize
            begin
                Process.waitpid( pid )
            rescue Errno::ECHILD
                @pids.delete pid
                return
            rescue Interrupt
                exit 0
            end
        end

        pid
    end

    def self.method_missing( sym, *args, &block )
        if instance.respond_to?( sym )
            instance.send( sym, *args, &block )
        else
            super( sym, *args, &block )
        end
    end

    def self.respond_to?( m )
        super( m ) || instance.respond_to?( m )
    end

    private

    def wmi
        @wmi ||= WIN32OLE.connect( 'winmgmts://' )
    end
end

end
end
