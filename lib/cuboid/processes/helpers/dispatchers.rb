# @param (see Cuboid::Processes::Dispatchers#spawn)
# @return (see Cuboid::Processes::Dispatchers#spawn)
def dispatcher_spawn( *args )
    Cuboid::Processes::Dispatchers.spawn( *args )
end

# @param (see Cuboid::Processes::Dispatchers#kill)
# @return (see Cuboid::Processes::Dispatchers#kill)
def dispatcher_kill( *args )
    Cuboid::Processes::Dispatchers.kill( *args )
end

# @param (see Cuboid::Processes::Dispatchers#killall)
# @return (see Cuboid::Processes::Dispatchers#killall)
def dispatcher_killall
    Cuboid::Processes::Dispatchers.killall
end

# @param (see Cuboid::Processes::Dispatchers#connect)
# @return (see Cuboid::Processes::Dispatchers#connect)
def dispatcher_connect( *args )
    Cuboid::Processes::Dispatchers.connect( *args )
end
