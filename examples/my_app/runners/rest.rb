require_relative '../application'

# Access to the #request and #response_* methods.
require_relative 'rest/helpers'

# Cuboid provides rudimentary process management for common entities, let's get them.
include Cuboid

# The REST API provides a nice and clean interface for Instances, Queues and
# Agents -- as always, if the Agent is connected to a Grid you can
# enjoy load-balancing.
#
# The REST interface can:
#   * spawn Instances on its own
#   * use a Agent to spawn Instances
#       * if the Agent is part of a Grid it enjoys load-balancing.
#   * use a Queue to spawn and manage Instances -- if the Queue is configured
#       with a Agent
#       * it will use it to spawn Instances
#           * if the Agent is part of a Grid it enjoys load-balancing.

# Simple example, no Agent nor Queue.
pid = MyApp.spawn( :rest, daemonize: true )
# Wait for the server to boot-up.
sleep 1 while request( :get ).code == 0

# None yet...
request :get, 'instances'
ap response_data
# {}

# Spawn an instance, configure it with :application options and run it.
request :post, 'instances', id: [1,2,3]
# :run
# [
#   [0] 1,
#   [1] 2,
#   [2] 3
# ]

# Unique identifier for this Instance.
instance_id = response_data['id']

# Access to the custom REST API.
request :get, "instances/#{instance_id}/custom/foo"
ap response_data
# "bar"

# Access to the custom REST API.
request :get, "instances/#{instance_id}/custom/rpc-foo"
ap response_data
# "bar"

# Access to the custom REST API.
request :get, "instances/#{instance_id}/custom/application_access"
ap response_data
# "foobar"

# Get Instance runtime info.
request :get, "instances/#{instance_id}"
ap response_data
# {
#   "status" => "done",
#   "busy" => false,
#   "application" => "CuboidApp",
#   "seed" => "e255b50f0f782052161423c5c3ddbdab",
#   "agent_url" => nil,
#   "queue_url" => nil,
#   "statistics" => {
#     "runtime" => 0.000547441
#   },
#   "errors" => [],
#   "messages" => []
# }

# Get the native report to access the Instances results.
request :get, "instances/#{instance_id}/report.crf"
ap Report.from_crf( response_data ).data
# [
#   [0] 1,
#   [1] 2,
#   [2] 3
# ]

# Get the REST API's JSON report to access results.
request :get, "instances/#{instance_id}/report.json"
ap MyApp.serializer.load( response_data['data'] )
# [
#   [0] 1,
#   [1] 2,
#   [2] 3
# ]

# There it now is, on the list of all running Instances.
request :get, 'instances'
ap response_data
# {
#   "a8630974a1bf4b8cc8a169fd1addbcc6" => {}
# }

# Shutdown the Instance, we're done with it.
request :delete, "instances/#{instance_id}"
ap response_data
# nil

# Gone.
request :get, 'instances'
ap response_data
# {}

Processes::Manager.kill pid
