# @param (see Cuboid::Processes::Instances#spawn)
# @return (see Cuboid::Processes::Instances#spawn)
def instance_spawn( *args )
    Cuboid::Processes::Instances.spawn( *args )
end

# @param (see Cuboid::Processes::Instances#grid_spawn)
# @return (see Cuboid::Processes::Instances#grid_spawn)
def instance_grid_spawn( *args )
    Cuboid::Processes::Instances.grid_spawn( *args )
end

# @param (see Cuboid::Processes::Instances#dispatcher_spawn)
# @return (see Cuboid::Processes::Instances#dispatcher_spawn)
def instance_dispatcher_spawn( *args )
    Cuboid::Processes::Instances.dispatcher.spawn( *args )
end

def instance_kill( url )
    Cuboid::Processes::Instances.kill url
end

# @param (see Cuboid::Processes::Instances#killall)
# @return (see Cuboid::Processes::Instances#killall)
def instance_killall
    Cuboid::Processes::Instances.killall
end

# @param (see Cuboid::Processes::Instances#connect)
# @return (see Cuboid::Processes::Instances#connect)
def instance_connect( *args )
    Cuboid::Processes::Instances.connect( *args )
end

# @param (see Cuboid::Processes::Instances#token_for)
# @return (see Cuboid::Processes::Instances#token_for)
def instance_token_for( *args )
    Cuboid::Processes::Instances.token_for( *args )
end
