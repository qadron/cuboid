require 'mcp'
require 'json'

require_relative '../rest/server/instance_helpers'

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
        ::Cuboid::Rest::Server::InstanceHelpers.class_variable_get( :@@instances )
    end

    def self.instrumented_call
        result = yield
        ::MCP::Tool::Response.new(
            [{ type: 'text', text: result.is_a?(String) ? result : JSON.pretty_generate(result) }]
        )
    rescue => e
        ::MCP::Tool::Response.new(
            [{ type: 'text', text: "error: #{e.class}: #{e.message}" }],
            error: true
        )
    end

    class ListInstances < ::MCP::Tool
        tool_name   'list_instances'
        description 'Returns the IDs of currently registered application instances.'
        input_schema(properties: {})

        def self.call( ** )
            CoreTools.instrumented_call do
                CoreTools.instances.each_with_object({}) do |(id, instance), h|
                    h[id] = { url: instance.respond_to?(:url) ? instance.url : nil }
                end
            end
        end
    end

    class SpawnInstance < ::MCP::Tool
        tool_name   'spawn_instance'
        description 'Spawn a new application instance and (optionally) start it with the given options. Returns the instance_id to use with /instances/:instance/<service>.'
        input_schema(
            properties: {
                options: {
                    type:        'object',
                    description: 'Application-specific options passed to instance.run(...). Pass {} to spawn without starting.',
                    additionalProperties: true
                },
                start: {
                    type:        'boolean',
                    description: 'When true (default) the spawned instance is started immediately by calling instance.run(options). When false the instance is registered idle.',
                    default:     true
                }
            }
        )

        def self.call( options: {}, start: true, ** )
            CoreTools.instrumented_call do
                instance = ::Cuboid::Processes::Instances.spawn(
                    application: ::Cuboid::Options.paths.application,
                    daemonize:   true
                )

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

        def self.call( instance_id:, ** )
            CoreTools.instrumented_call do
                instance = CoreTools.instances[instance_id]
                raise "unknown instance: #{instance_id}" if !instance

                (instance.shutdown rescue nil)
                CoreTools.instances.delete( instance_id ).close
                "killed: #{instance_id}"
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
