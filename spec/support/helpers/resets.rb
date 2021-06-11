# Order is important.
INSTANCES = [
    Cuboid::Application
]
INSTANCES.each(&:_spec_instances_collect!)

def reset_options
    options = Cuboid::Options
    options.reset

    options.paths.logs      = spec_path + 'support/logs/'
    options.paths.reports   = spec_path + 'support/reports/'
    options.paths.snapshots = spec_path + 'support/snapshots/'
    options.snapshot.path   = options.paths.snapshots

    options.rpc.server_address = '127.0.0.1'

    options
end

def cleanup_instances
    INSTANCES.each do |i|
        i._spec_instances_cleanup
    end
end

def reset_framework
    Cuboid::UI::OutputInterface.initialize
    # Cuboid::UI::Output.debug_on( 999999 )
    # Cuboid::UI::Output.verbose_on
    # Cuboid::UI::Output.mute

    Cuboid::Application.reset
end

def reset_all
    reset_options
    reset_framework
end

def processes_killall
    instance_killall
    dispatcher_killall
    scheduler_killall
    process_killall
    process_kill_reactor
end

def killall
    processes_killall
    web_server_killall
end
