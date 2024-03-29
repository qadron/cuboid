require_relative '../application'

# Cuboid provides rudimentary process management for common entities, let's get them.
include Cuboid::Processes

puts
ap '=' * 80
ap "#{'-' * 35} Instance #{'-' * 35}"
ap '=' * 80
puts

# Spawn a single instance just for us to play with; test it maybe or some such.
myapp = MyApp.spawn( :instance, daemonize: true )

# Access to the custom RPC API.
ap myapp.custom.foo
# "bar"

ap myapp.progress
# {
#   :status => :ready,
#   :busy => false,
#   :application => "MyApp",
#   :seed => "13100eef17435089c7c8f887e076d6e2",
#   :agent_url => nil,
#   :scheduler_url => nil,
#   :statistics => {
#     :runtime => 0
#   },
#   :messages => []
# }

# Run and provide options.
myapp.run( id: [1, 2, 3] )
# :run
# [
#   [0] 1,
#   [1] 2,
#   [2] 3
# ]

# Custom RPC API call that accesses the application.
ap myapp.custom.application_access
# "foobar"

# Get the native Cuboid::Report to access the Instances results.
ap myapp.generate_report.data
# [
#   [0] 1,
#   [1] 2,
#   [2] 3
# ]

# Don't forget to shutdown Instances once you're done.
myapp.shutdown


puts
ap '=' * 80
ap "#{'-' * 34} Agent #{'-' * 34}"
ap '=' * 80
puts

# Setup a Agent to provide Instances to us.
agent = MyApp.spawn( :agent, daemonize: true )

# This will call our custom aggregator service, no Instances yet though.
ap agent.custom.foo
# {}
ap agent.custom.application_access
# {}

5.times do |i|
    myapp_info = agent.spawn

    myapp = MyApp.connect( myapp_info )
    myapp.run( id: i )
    # :run
    # 0

    # This will call our custom aggregator service.
    # At the last run it will show something like:
    ap agent.custom.foo
    # {
    #     "127.0.0.1:63967" => "bar",
    #      "127.0.0.1:8414" => "bar",
    #     "127.0.0.1:11643" => "bar",
    #     "127.0.0.1:40270" => "bar",
    #     "127.0.0.1:44070" => "bar"
    # }
    ap agent.custom.application_access
    # {
    #     "127.0.0.1:63967" => "foobar",
    #      "127.0.0.1:8414" => "foobar",
    #     "127.0.0.1:11643" => "foobar",
    #     "127.0.0.1:40270" => "foobar",
    #     "127.0.0.1:44070" => "foobar"
    # }
end

puts
ap '=' * 80
ap "#{'-' * 37} Grid #{'-' * 37}"
ap '=' * 80
puts

# Cooler still, setup a Agent Grid to provide Instances and load-balancing.
#
# Of course in a real setup each Agent would be on its own machine.
grid = []

# 1st node.
grid << MyApp.spawn( :agent, daemonize: true )

# 2nd node.
#
# All that needs to be done is to pass one of the others as a peer and
# they'll mesh it up themselves.
grid << MyApp.spawn( :agent, peer: grid.sample.url, daemonize: true )

# 3rd node.
grid << MyApp.spawn( :agent, peer: grid.sample.url, daemonize: true )

5.times do |i|
    # Pick Agents at random; not necessary but fun.
    node = grid.sample

    # This will be an Instance from the least burdened Agent machine, not
    # necessarily the one we asked -- well, here they are all on the same
    # machine but you get the point.
    app_info = node.spawn

    # There are 2 available strategies for workload distribution:
    #   * Horizontal (default) -- Provides Instances from the least burdened Agent.
    #       * node.spawn( strategy: horizontal )
    #   * Vertical  -- Provides Instances from the most burdened Agent.
    #       * node.spawn( strategy: vertical )

    myapp = MyApp.connect( app_info )
    myapp.run( id: [i, node.url] )
    # :run
    # [
    #   [0] 0,
    #   [1] "127.0.0.1:18476"
    # ]
end

grid.each do |node|
    # This will call our custom aggregator service.
    ap node.custom.foo
    ap node.custom.application_access
end

# Point is, we don't need to setup a topology manually nor do we care which
# Agent we're using at any given time, the Grid will strive for best
# results for us.

# Agents don't expose their #shutdown method, programatically, we need
# to get a bit harsh.
Agents.killall

puts
ap '=' * 80
ap "#{'-' * 34} Scheduler #{'-' * 35}"
ap '=' * 80
puts

# Schedulers can be used to spawn and manage Instances from the same machine,
# a Agent or a Agent Grid.
#
# Basically, you can push Instance options to the Scheduler and that's it.
# If the Scheduler is configured with a Agent then it'll get Instances from
# there, and if the Agent is part of a Grid then we'll also enjoy load-balancing.
#
# Else, Instances are spawned on the same machine by the Scheduler itself.
scheduler = MyApp.spawn( :scheduler, daemonize: true )

# Push Instance options for some jobs.
5.times do |i|
    scheduler.push( id: i )
    # :run
    # 3
end
# No need to do anything else, the Instances are managed internally by the
# Scheduler and reports are retrieved and saved to disk.
#
# You could also see it as a pipe to Instances, that handles
# monitoring/management as well.

# If one already has an Instance, management can be handed over to the Scheduler
# at any time.
myapp = MyApp.spawn( :instance, daemonize: true )
scheduler.attach myapp.url, myapp.token
myapp.run( id: [1, 2, 3] )
# :run
# [
#   [0] 1,
#   [1] 2,
#   [2] 3
# ]

# Detaching and different types of stats are also available.

# Wait for Instances to complete and the Scheduler to empty.
sleep 1 while scheduler.running.any? || scheduler.any?

# Get the report location of each Instance.
ap scheduler.completed
# {
#   "be8de095c6f8602cff322d554c75101e" => "/Users/zapotek/workspace/ng/cuboid/reports/be8de095c6f8602cff322d554c75101e.crf",
#   "84293a20cefafbaa983fc3e1faa8409d" => "/Users/zapotek/workspace/ng/cuboid/reports/84293a20cefafbaa983fc3e1faa8409d.crf",
#   "05c6936e8e7e8f2569bf396438988a6a" => "/Users/zapotek/workspace/ng/cuboid/reports/05c6936e8e7e8f2569bf396438988a6a.crf",
#   "d77c57aa784d3a15a0e279aa56a95441" => "/Users/zapotek/workspace/ng/cuboid/reports/d77c57aa784d3a15a0e279aa56a95441.crf",
#   "342af23470c9fdeb7dfe9feceb6df911" => "/Users/zapotek/workspace/ng/cuboid/reports/342af23470c9fdeb7dfe9feceb6df911.crf",
#   "7f7841d2f68694ee9dac57fa0de3d31c" => "/Users/zapotek/workspace/ng/cuboid/reports/7f7841d2f68694ee9dac57fa0de3d31c.crf"
# }

Schedulers.killall
