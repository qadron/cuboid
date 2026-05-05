require 'mcp'
require 'json'

require_relative '../server/instance_helpers'

module Cuboid
module MCP

# Framework-level MCP tools — instance management. Mounted by
# `Cuboid::MCP::Server::Dispatcher` at the top-level `/mcp` endpoint
# so an MCP-only client has a way to spawn / list / kill engine
# instances without going through the REST surface.
#
# Per-instance per-service tools (the application-gem-supplied ones
# registered via `mcp_service_for`) live at
# `/instances/:instance/<service>` and pick up where these leave off:
# the typical client lifecycle is
#
#     spawn_instance → returns instance_id
#     POST /instances/<instance_id>/<service> { tools/call ... }
#     ...
#     kill_instance(id: instance_id)
module CoreTools

    # Direct access to the shared in-memory map populated by REST POST
    # /instances + the scheduler-sync flow + spawn_instance below.
    # Module-level so tools don't have to mix in the InstanceHelpers
    # context (which carries Sinatra-helper assumptions like `session`).
    def self.instances
        ::Cuboid::Server::InstanceHelpers.instances
    end

    # Wraps a tool body. Returns an MCP::Tool::Response that always
    # carries a JSON-encoded `text` content for clients that don't yet
    # consume `structuredContent`, and — when the result is structured
    # (Hash/Array) — also a `structuredContent` block matching the
    # tool's `output_schema`. A raised exception is captured and
    # returned as an MCP error response so the MCP server itself stays
    # up for the next call.
    def self.instrumented_call
        result = yield

        if result.is_a?( String )
            ::MCP::Tool::Response.new(
                [{ type: 'text', text: result }]
            )
        else
            ::MCP::Tool::Response.new(
                [{ type: 'text', text: JSON.pretty_generate( result ) }],
                structured_content: result
            )
        end
    rescue => e
        ::MCP::Tool::Response.new(
            [{ type: 'text', text: "error: #{e.class}: #{e.message}" }],
            error: true
        )
    end

    class ListInstances < ::MCP::Tool
        tool_name   'list_instances'
        description 'Returns the currently-registered application instances as a map of `instance_id` → metadata.'
        input_schema(properties: {})
        output_schema(
            properties: {
                instances: {
                    type:        'object',
                    description: 'Map of instance_id (string) → its metadata.',
                    additionalProperties: {
                        type: 'object',
                        properties: {
                            url: {
                                type:        ['string', 'null'],
                                description: 'host:port the engine instance is bound to (nil for unreachable / scheduler-only entries).'
                            }
                        }
                    }
                }
            },
            required: ['instances']
        )

        def self.call( ** )
            CoreTools.instrumented_call do
                instances = CoreTools.instances.each_with_object({}) do |(id, instance), h|
                    h[id] = { url: instance.respond_to?(:url) ? instance.url : nil }
                end
                { instances: instances }
            end
        end
    end

    class SpawnInstance < ::MCP::Tool
        tool_name   'spawn_instance'
        description 'Spawn a new application instance and (optionally) start it. Returns the `instance_id`; pass that to every per-service tool (`scan_progress`, `scan_entries`, etc.) as their `instance_id` argument. To spawn an instance without running anything in it, pass `start: false` — passing an empty `options: {}` does NOT skip the run.'
        input_schema(
            properties: {
                options: {
                    type:        'object',
                    description: 'Application-specific run-time options forwarded to `instance.run(...)`. Shape is defined by the running application — consult its docs for valid keys (e.g. for SCNR/Spectre and RKN/Apex this is the SCNR engine Options DSL: `url`, `scope`, `audit`, `http`, `checks`, `plugins`, …). Use `start: false` to spawn an idle instance with no run options at all.',
                    additionalProperties: true
                },
                start: {
                    type:        'boolean',
                    description: 'When true (default) the spawned instance is started immediately by calling `instance.run(options)`. When false the instance is registered without running anything (a "registered-but-not-started" handle); use this when you want to spawn now and supply options later via another channel.',
                    default:     true
                }
            }
        )

        output_schema(
            properties: {
                instance_id: {
                    type:        'string',
                    description: 'Engine-instance handle. Pass this back as `instance_id` to every `scan_*` tool.'
                },
                url: {
                    type:        ['string', 'null'],
                    description: 'host:port the engine instance is reachable at over RPC.'
                }
            },
            required: ['instance_id']
        )

        def self.call( options: {}, start: true, ** )
            CoreTools.instrumented_call do
                # Goes through the shared spawner so a configured Agent
                # provisions the instance over the grid; falls back to
                # local `Processes::Instances.spawn` when no agent is set.
                instance = ::Cuboid::Server::InstanceHelpers.spawn

                if start
                    begin
                        instance.run( options )
                    rescue => e
                        # Roll back the spawn — leaking a half-initialised
                        # process is worse than leaking the error.
                        (instance.shutdown rescue nil)
                        raise e
                    end
                end

                CoreTools.instances[instance.token] = instance
                { instance_id: instance.token, url: instance.url }
            end
        end
    end

    class KillInstance < ::MCP::Tool
        tool_name   'kill_instance'
        description 'Shut down and unregister an application instance by instance_id.'
        input_schema(
            properties: {
                instance_id: {
                    type:        'string',
                    description: 'instance_id returned by spawn_instance / present in list_instances.'
                }
            },
            required: ['instance_id']
        )
        output_schema(
            properties: {
                killed: {
                    type:        'string',
                    description: 'instance_id of the instance that was shut down and removed.'
                }
            },
            required: ['killed']
        )

        def self.call( instance_id:, ** )
            CoreTools.instrumented_call do
                instance = CoreTools.instances[instance_id]
                raise "unknown instance: #{instance_id}" if !instance

                (instance.shutdown rescue nil)
                CoreTools.instances.delete( instance_id ).close
                { killed: instance_id }
            end
        end
    end

    TOOLS = [ ListInstances, SpawnInstance, KillInstance ].freeze

    def self.tools
        TOOLS
    end

end

end
end
