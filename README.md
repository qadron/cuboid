# Cuboid Framework -- a decentralized & distributed computing framework in Ruby.

## Summary

The Cuboid Framework offers the possibility of easily creating decentralized and
distributed applications in Ruby.

In hipper terms, you can very easily setup your own specialized _Cloud_ or
_Cloud_ within a _Cloud_.

In older-fashioned terms you can build load-balanced, on-demand, clustered applications and even super-computers -- 
see [Peplum](https://github.com/peplum/).

It offers:

* Load-balancing of _**Instances**_ via a network (_**Grid**_) of _**Agents**_.
  * No need to setup a topology manually, _**Agents**_ will reach
    convergence on their own, just point them to an existing _**Grid**_ member.
  * Scaling up and down can be easily achieved by _plugging_ or _unplugging_ nodes.
  * Horizontal (`default`) and vertical workload distribution strategies available.
  * Fault tolerant -- one application per process (_**Instance**_).
  * Self-healing -- keeps an eye out for disappearing and also re-appearing members.
* A clean and simple framework for application development.
  * Basically, Ruby -- and all the libraries and extensions that come with it.
* Events (_pause_, _resume_, _abort_, _suspend_, _restore_).
  * Suspend to disk is a cinch by automatically creating a _**snapshot**_
    of the runtime environment of the application and storing it to disk
    for later restoration of state and data.
    * **Also allows for running job transfers.**
* Management of Instances via RPC or REST APIs.
    * Aside from what **Cuboid** uses, custom serializers can be specified for
      application related objects.
* Developer freedom.
  * Apart from keeping _Data_ and _State_ separate not many other rules to follow.
    * Only if interested in _suspensions_ and can also be left to the last minute
      if necessary -- in cases of `Ractor` enforced isolation for example.

## Entities

### Application

A Ruby `class` which inherits from `Cuboid::Application` and complies with a few
simple specifications; at the least, a `#run` method, serving as the execution
entry point.

The application can use the following methods to better take advantage of the
framework:

  * `#validate_options( options )` -- Validates _**Application**_ options.
  * `#provision_cores( Fixnum )` -- Specifies the maximum amount of cores the
    _**Application**_ will be using.
  * `#provision_memory( Fixnum )` -- Specifies the maximum amount of RAM the
    _**Application**_ will be using.
  * `#provision_disk( Fixnum )` -- Specifies the maximum amount of disk space the
    _**Application**_ will be using.
  * `#handler_for( Symbol, Symbol )` -- Specifies methods to handle the following events:
    * `:pause`
    * `:resume`
    * `:abort`
    * `:suspend`
    * `:restore`
  * `instance_service_for( Symbol, Class )` -- Adds a custom _**Instance**_ RPC API.
  * `rest_service_for( Symbol, Module )` -- Hooks-up to the _**REST**_ service to provide a custom REST API.
  * `agent_service_for( Symbol, Class )` -- Hooks-up to the _**Agent**_ to provide a custom RPC API.
  * `mcp_service_for( Symbol, Module )` -- Registers an _**MCP**_ service module
    (its `tools` / `prompts` / `resources` / `read_resource` are exposed at
    `/mcp` and routed per-instance via `instance_id`).
  * `mcp_app_tool( MCP::Tool )` -- Ships an app-level _**MCP**_ tool at the
    top-level `/mcp` endpoint, alongside `list_instances` / `spawn_instance`
    / `kill_instance` -- no `instance_id` required (catalogue / metadata
    tools the client may want to consult before spawning anything).
  * `mcp_authenticate_with { |bearer_token| ... }` -- Bearer-token
    validator for the _**MCP**_ transport; block returns a truthy
    principal on success, `nil` to reject. Without one the server
    accepts unauthenticated traffic.
  * `serialize_with( Module )` -- A serializer to be used for:
    * `#options`
    * `Report#data`
    * `Runtime` `Snapshot`

Access is also available to:

  * `#options` -- Passed options.
  * `#runtime` -- The _**Application**_'s `Runtime` environment, as a way to
    store and access _state_ and _data_. Upon receiving a _suspend_ event, the
    `Runtime` will be stored to disk as a `Snapshot` for later restoration.
    * `Runtime#state` -- State accessor.
    * `Runtime#data` -- Data accessor.
  * `#report( data )` -- Stores given `data`, to be included in a later generated
    `Report` and accessed via `Report#data`.

### Instance

An _**Instance**_ is a process container for a **Cuboid** _**Application**_;
**Cuboid** is application-centric and follows the one process-per-application principle.

This is in order to enforce isolation (_state_, _data_, _fault_) between
_**Applications**_, take advantage of _OS_ task management and generally keep
things simple.

### Agent

A _**Agent**_ is a server which awaits for _**Instance**_ spawn requests
(`spawn` calls) upon which it spawns and passes the _**Instance**_'s
connection info to the client.

The client can then proceed to use the _**Instance**_ to run and generally manage
the contained _**Application**_.

#### Grid

A _**Agent**_ _**Grid**_ is a software mesh network of _**Agent**_
servers, aimed towards providing automated _load-balancing_ based on available
system resources and each _**Application**_'s provisioning configuration.

No _topology_ needs to be specified, the only configuration necessary is
providing any existing _**Grid**_ member upon start-up and the rest will be
sorted out automatically.

The network is _self-healing_ and will monitor _node_ connectivity, taking steps
to ensure that neither server nor network conditions will disrupt spawning.

##### Scalability

_**Agents**_ can be easily _plugged_ to or _unplugged_ from the _**Grid**_
to scale up or down as necessary.

_Plugging_ happens at boot-time and _unplugging_ can take place via the available
_APIs_.

### Scheduler

The _**Scheduler**_ is a server which:

  1. Accepts _**Application**_ options. 
  2. Stores them in a queue. 
  3. Pops options and passes them to spawned _**Instances**_.
  4. Monitors _**Instance**_ progress.
  5. Upon _**Application**_ completion stores report to disk.
  6. Shuts down the _**Instance**_.

#### Agent

The _**Scheduler**_ can be configured with a _**Agent**_, upon which case,
it will use it to spawn _**Instances**_.

If the _**Agent**_ is a _**Grid**_ member then the _**Scheduler**_ will
also enjoy _load-balancing_ features. 

## APIs

### Local

Local access can call upon via the `Cuboid::Application` API and the API defined by the 
_**Application**_ itself.

### RPC

A simple RPC is employed, specs for 3rd party implementations can be found at:

https://github.com/toq/arachni-rpc/wiki

Each _**Application**_ can extend upon this and expose an API via its _**Instance**_'s 
RPC interface.

### REST

A REST API is also available, taking advantage of HTTP sessions to make progress
tracking easier.

The REST interface is basically a web _**Agent**_ and centralised point of
management for the rest of the entities.

Each _**Application**_ can extend upon this and expose an API via its _**REST**_ 
service's interface.

### MCP

An [Model Context Protocol][mcp] server is also available, allowing AI clients
(Claude Desktop / Code, Cursor, Continue, anything that speaks MCP) to drive
_**Applications**_ end-to-end over a single Streamable-HTTP endpoint
(`POST /mcp` for request/response, `GET /mcp` for the server-initiated SSE
notifications channel).

Spin up the MCP server with:

```ruby
MyApp.spawn(:mcp, ssl: { ... })
```

[mcp]: https://modelcontextprotocol.io/

#### Tools

Three tools ship at the top-level endpoint by default
(`Cuboid::MCP::CoreTools`):

| Tool             | Required        | Returns                       |
|------------------|-----------------|-------------------------------|
| `list_instances` | --              | `{ instances: { <id>: { url } } }` |
| `spawn_instance` | --              | `{ instance_id, url, live: { notification_method } }` |
| `kill_instance`  | `instance_id`   | `{ killed: <id> }`            |

Per-service tools (registered via `mcp_service_for`) take an `instance_id`
argument and are dispatched to the matching engine instance. App-level
catalogue tools (registered via `mcp_app_tool`) live at the top-level
endpoint without an `instance_id` requirement.

#### Live channel

Every `spawn_instance` attaches the calling MCP session to a live
notification stream — every interesting state change inside the engine
arrives as a JSON-RPC `notifications/<brand>/live` notification on the SSE
half of the transport, where `<brand>` is derived from the umbrella's
`shortname` (falling back to `cuboid` for bare-cuboid builds). The spawn
response carries `live.notification_method` so clients don't have to
hard-code the brand.

Status payloads emitted by the live plugin: `started` (synthetic, on plugin
attach) → `preparing` → `scanning` → `auditing` → `cleanup` → `done` (or
`aborted`) → `exited` (synthetic, fired from the live plugin's `at_exit`
when the engine subprocess actually exits — only after `kill_instance` and
only on a graceful unwind; SIGKILL skips it).

Pass `live: false` to `spawn_instance` to opt out (poll `scan_progress`
instead) -- recommended for non-MCP integrations and any application that
disables the engine-side `live` plugin via `validate_options`.

#### Auth

Authentication is opt-in via `mcp_authenticate_with`. With a registered
validator the server requires `Authorization: Bearer <token>` on every
request and returns `401 Unauthorized` otherwise (RFC 6750 -- 
`WWW-Authenticate: Bearer realm="MCP", error=…`). The resolved principal is
stashed at `env['cuboid.mcp.auth']` for downstream middleware.

#### Resources & prompts

`Cuboid::MCP` also wires the standard `resources/list` / `resources/read`
and `prompts/list` / `prompts/get` MCP plumbing. Service modules can ship
markdown / JSON resources (glossaries, options references, presets) and
prompts (canned operator workflows) via `tools` / `prompts` / `resources`
/ `read_resource` class methods on the registered handler. The Spectre /
Apex umbrellas use this to ground AI clients without out-of-band knowledge
-- the tool / prompt / resource descriptions ARE the docs.

## Examples

### MyApp

Tutorial application going over different APIs and **Cuboid** _**Application**_
options and specification.

See `examples/my_app`.

### Parallel code on same host

To run code in parallel on the same machine utilising multiple cores, with each
instance isolated to its own process, you can use something like the following:

`sleeper.rb`:
```ruby
require 'cuboid'

class Sleeper < Cuboid::Application

    def run
        sleep options['time']
    end

end
```

```ruby
require_relative 'sleeper'

sleepers = []
sleepers << Sleeper.spawn( :instance, daemonize: true )
sleepers << Sleeper.spawn( :instance, daemonize: true )
sleepers << Sleeper.spawn( :instance, daemonize: true )

sleepers.each do |sleeper|
    sleeper.run( time: 5 )
end

sleep 0.1 while sleepers.map(&:busy?).include?( true )
```

    time bundle exec ruby same_host.rb
    [...]
    real    0m6,506s
    user    0m0,423s
    sys     0m0,063s

### Parallel code on different hosts

In this example we'll be using `Agents` to spawn instances from 3 different hosts.

#### Host 1

```ruby
require_relative 'sleeper'

Sleeper.spawn( :agent, port: 7331 )
```

    bundle exec ruby multiple_hosts_1.rb

#### Host 2

```ruby
require_relative 'sleeper'

Sleeper.spawn( :agent, port: 7332, peer: 'host1:7331' )
```

    bundle exec ruby multiple_hosts_2.rb

#### Host 3

```ruby
require_relative 'sleeper'

grid_agent = Sleeper.spawn( :agent, port: 7333, peer: 'host1:7331', daemonize: true )

sleepers = []
3.times do
    connection_info = grid_agent.spawn
    sleepers << Sleeper.connect( connection_info )
end

sleepers.each do |sleeper|
    sleeper.run( time: 5 )
end

sleep 0.1 while sleepers.map(&:busy?).include?( true )
```

    time bundle exec ruby multiple_hosts_3.rb
    real    0m7,318s
    user    0m0,426s
    sys     0m0,091s


_You can replace `host1` with `localhost` and run all examples on the same machine._

### Driving an Application over MCP

`mcp_app_tool` ships a top-level catalogue tool (no `instance_id`); 
`mcp_service_for` ships per-instance tools whose first arg is `instance_id`.

`sleeper_mcp.rb`:
```ruby
require 'cuboid'
require 'mcp'

# A top-level catalogue tool — no `instance_id` required.
class Ping < MCP::Tool
    tool_name   'ping'
    description 'Connectivity check; returns "pong".'
    input_schema(properties: {}, type: 'object')
    def self.call( ** )
        MCP::Tool::Response.new([{ type: 'text', text: 'pong' }])
    end
end

# A per-instance tool routed to the engine identified by `instance_id`.
module SleeperMCP
    class HowLong < MCP::Tool
        tool_name   'how_long'
        description "Reports the sleeper's progress."
        input_schema(
            properties: { instance_id: { type: 'string' } },
            required:   ['instance_id'],
            type:       'object'
        )

        def self.call( instance_id:, server_context: nil, ** )
            instance = server_context[:instance]
            MCP::Tool::Response.new([{
                type: 'text',
                text: instance.progress.to_json
            }])
        end
    end

    TOOLS = [HowLong].freeze
    def self.tools; TOOLS; end
end

class Sleeper < Cuboid::Application
    mcp_app_tool        Ping
    mcp_service_for     :sleeper, SleeperMCP

    def run; sleep options['time']; end
end

# Spawn the MCP server (Streamable HTTP at /mcp on the default RPC port).
Sleeper.spawn(:mcp)
```

```bash
bundle exec ruby sleeper_mcp.rb
```

In another shell, the standard MCP handshake:

```bash
SID=$(curl -sS -i -X POST http://127.0.0.1:7331/mcp \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    --data '{"jsonrpc":"2.0","id":1,"method":"initialize",
             "params":{"protocolVersion":"2025-06-18",
                       "capabilities":{},
                       "clientInfo":{"name":"curl","version":"0"}}}' \
    | awk -F': ' '/[Mm]cp-[Ss]ession-[Ii]d/ {gsub(/\r/,"",$2); print $2}')

curl -sS -X POST http://127.0.0.1:7331/mcp \
    -H "Mcp-Session-Id: $SID" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    --data '{"jsonrpc":"2.0","method":"notifications/initialized"}'

# 1. The catalogue tool — no instance_id needed.
curl -sS -X POST http://127.0.0.1:7331/mcp \
    -H "Mcp-Session-Id: $SID" -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    --data '{"jsonrpc":"2.0","id":2,"method":"tools/call",
             "params":{"name":"ping","arguments":{}}}'
# → "pong"

# 2. Spawn an instance, then call the per-instance tool.
SPAWN=$(curl -sS -X POST http://127.0.0.1:7331/mcp \
    -H "Mcp-Session-Id: $SID" -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    --data '{"jsonrpc":"2.0","id":3,"method":"tools/call",
             "params":{"name":"spawn_instance",
                       "arguments":{"options":{"time":5},"start":true}}}')
IID=$(echo "$SPAWN" | sed -n 's/^data: //p' | jq -r '.result.structuredContent.instance_id')

curl -sS -X POST http://127.0.0.1:7331/mcp \
    -H "Mcp-Session-Id: $SID" -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    --data "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/call\",
             \"params\":{\"name\":\"how_long\",\"arguments\":{\"instance_id\":\"$IID\"}}}"
# → progress JSON

# 3. Tear down.
curl -sS -X POST http://127.0.0.1:7331/mcp \
    -H "Mcp-Session-Id: $SID" -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    --data "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"tools/call\",
             \"params\":{\"name\":\"kill_instance\",\"arguments\":{\"instance_id\":\"$IID\"}}}"
```

The `live` channel (SSE on `GET /mcp`) is attached automatically;
omit it with `live: false` on `spawn_instance`.

## Users

* [QMap](https://github.com/qadron/qmap) --  A distributed network mapper/security scanner powered by [nmap](http://nmap.org/).
* [Peplum](https://github.com/peplum/peplum) -- A distributed parallel processing solution -- allows you to build Beowulf
(or otherwise) clusters and even super-computers.

## License

Please see the _LICENSE.md_ file.
