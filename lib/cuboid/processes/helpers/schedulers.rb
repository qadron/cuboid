# @param (see Cuboid::Processes::Schedulers#spawn)
# @return (see Cuboid::Processes::Schedulers#spawn)
def scheduler_spawn( *args )
    Cuboid::Processes::Schedulers.spawn( *args )
end

# @param (see Cuboid::Processes::Schedulers#kill)
# @return (see Cuboid::Processes::Schedulers#kill)
def scheduler_kill( *args )
    Cuboid::Processes::Schedulers.kill( *args )
end

# @param (see Cuboid::Processes::Schedulers#killall)
# @return (see Cuboid::Processes::Schedulers#killall)
def scheduler_killall
    Cuboid::Processes::Schedulers.killall
end

# @param (see Cuboid::Processes::Schedulers#connect)
# @return (see Cuboid::Processes::Schedulers#connect)
def scheduler_connect( *args )
    Cuboid::Processes::Schedulers.connect( *args )
end
