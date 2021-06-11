# @param (see Cuboid::Processes::Manager#kill_reactor)
# @return (see Cuboid::Processes::Manager#kill_reactor)
def process_kill_reactor( *args )
    Cuboid::Processes::Manager.kill_reactor( *args )
end

# @param (see Cuboid::Processes::Manager#kill)
# @return (see Cuboid::Processes::Manager#kill)
def process_kill( *args )
    Cuboid::Processes::Manager.kill( *args )
end

# @param (see Cuboid::Processes::Manager#killall)
# @return (see Cuboid::Processes::Manager#killall)
def process_killall( *args )
    Cuboid::Processes::Manager.killall( *args )
end

# @param (see Cuboid::Processes::Manager#kill_many)
# @return (see Cuboid::Processes::Manager#kill_many)
def process_kill_many( *args )
    Cuboid::Processes::Manager.kill_many( *args )
end
