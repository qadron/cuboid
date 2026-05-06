require 'base64'

$options = Marshal.load( Base64.strict_decode64( ARGV.pop ) )

if !$options[:without_cuboid]
    require 'cuboid'

    include Cuboid

    cuboid_options = Marshal.load( Base64.strict_decode64( ENV['CUBOID_SPAWN_OPTIONS'] ) )
    Options.update cuboid_options

    require( Options.paths.application ) if Options.paths.application
else
    if Gem.win_platform?
        require 'Win32API'
        require 'win32ole'
    end
end

def ppid
    $options[:ppid]
end

def parent_alive?
    # Windows is not big on POSIX so try it its own way if possible.
    if Gem.win_platform?
        begin
            alive = false
            wmi = WIN32OLE.connect( 'winmgmts://' )
            processes = wmi.ExecQuery( "select ProcessId from win32_process where ProcessID='#{ppid}'")
            processes.each do |proc|
                proc.ole_free
                alive = true
            end
            processes.ole_free
            wmi.ole_free

            return alive
        rescue WIN32OLERuntimeError
        end
    end

    !!(Process.kill( 0, ppid ) rescue false)
end

def puts_stderr( str )
    return if $stderr.closed?

    $stderr.puts str
rescue
end

# Parent-death watchdog. If the spawning process dies (rspec
# crashed / Ctrl-C'd before the after-hooks could run, MCP server
# SIGKILL'd, host shell exited) the engine subprocess gets
# reparented to init and would otherwise survive forever. Poll the
# **original** spawn-time parent pid (`ppid`) — not Process.ppid,
# which goes to 1 the moment we daemonise — and force a clean exit
# the moment ESRCH says the parent is gone.
#
# Polling cadence is 5 s: cheap, fires before tmpdirs accumulate.
# Skipped when no `ppid` was stamped on the options (manual
# invocations / tests that don't go through Manager.spawn).
PARENT_WATCHDOG_INTERVAL = 5.0

if ppid && ppid > 0
    Thread.new do
        loop do
            sleep PARENT_WATCHDOG_INTERVAL
            break if !parent_alive?
        end

        # Parent's gone. Try a graceful exit first so at_exit
        # handlers fire (Cuboid_<pid> tmpdir cleanup, the live
        # plugin's `exited` push, etc.); fall back to SIGKILL ourselves
        # if a non-daemon Application thread refuses to release the
        # runtime.
        Thread.new do
            sleep 5
            Process.kill( 'KILL', Process.pid ) rescue nil
        end

        main = Thread.main
        if main && main.alive? && main != Thread.current
            main.raise( SystemExit.new( 0 ) ) rescue nil
        end
    end
end

load ARGV.pop
