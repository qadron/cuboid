# @param (see Cuboid::Processes::Agents#spawn)
# @return (see Cuboid::Processes::Agents#spawn)
def agent_spawn( *args )
    Cuboid::Processes::Agents.spawn( *args )
end

# @param (see Cuboid::Processes::Agents#kill)
# @return (see Cuboid::Processes::Agents#kill)
def agent_kill( *args )
    Cuboid::Processes::Agents.kill( *args )
end

# @param (see Cuboid::Processes::Agents#killall)
# @return (see Cuboid::Processes::Agents#killall)
def agent_killall
    Cuboid::Processes::Agents.killall
end

# @param (see Cuboid::Processes::Agents#connect)
# @return (see Cuboid::Processes::Agents#connect)
def agent_connect( *args )
    Cuboid::Processes::Agents.connect( *args )
end
