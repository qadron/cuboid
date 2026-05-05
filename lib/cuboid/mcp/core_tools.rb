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
        description 'Spawn a new application instance and (optionally) start it. Returns the `instance_id`; pass that to every per-service tool (`scan_progress`, `scan_entries`, etc.) as their `instance_id` argument. Pass `start: false` to spawn an idle instance with no run; an empty `options: {}` does NOT skip the run. Scan events stream live by default — listen for the `notifications/<brand>/live` JSON-RPC notification (the exact method is brand-derived; the spawn response\'s `live.notification_method` tells you what to subscribe to). Pass `live: false` to opt out and poll instead.'
        input_schema(
            properties: {
                options: {
                    type:        'object',
                    description: 'Application-specific run-time options forwarded to `instance.run(...)`. Shape is defined by the running application — consult its docs for valid keys. Use `start: false` to spawn an idle instance with no run options at all.',
                    additionalProperties: true
                },
                start: {
                    type:        'boolean',
                    description: 'When true (default) the spawned instance is started immediately by calling `instance.run(options)`. When false the instance is registered without running anything (a "registered-but-not-started" handle); use this when you want to spawn now and supply options later via another channel.',
                    default:     true
                },
                live: {
                    type:        'boolean',
                    description: 'Default true — scan events stream to the calling session as the brand-derived `notifications/<brand>/live` JSON-RPC notification. Set to false to opt out and poll instead.',
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
                },
                live: {
                    type:        'object',
                    description: 'Present when live streaming is on. Tells the client which notification method to listen for.',
                    properties:  {
                        notification_method: { type: 'string', description: 'JSON-RPC method to subscribe to — brand-derived (`notifications/<brand>/live`).' }
                    }
                }
            },
            required: ['instance_id']
        )

        def self.call( options: {}, start: true, live: true, server_context: nil, ** )
            CoreTools.instrumented_call do
                # Goes through the shared spawner so a configured Agent
                # provisions the instance over the grid; falls back to
                # local `Processes::Instances.spawn` when no agent is set.
                instance = ::Cuboid::Server::InstanceHelpers.spawn

                live_attached = false
                if live
                    options = CoreTools.inject_live_plugin(
                        options,
                        instance_id:    instance.token,
                        server_context: server_context
                    )
                    live_attached = options != nil && options['plugins'] && options['plugins']['live']
                end

                if start
                    begin
                        instance.run( options )
                    rescue => e
                        # Roll back the spawn — leaking a half-initialised
                        # process is worse than leaking the error. Drop
                        # any live registration we made above.
                        (instance.shutdown rescue nil)
                        ::Cuboid::MCP::Live.unregister( instance.token ) if live_attached
                        raise e
                    end
                end

                CoreTools.instances[instance.token] = instance

                result = { instance_id: instance.token, url: instance.url }
                if live_attached
                    result[:live] = {
                        notification_method: ::Cuboid::MCP::Live.notification_method
                    }
                end
                result
            end
        end
    end

    # Mutate (a copy of) the user's `options` so the engine subprocess
    # loads the `live` plugin pointed at this MCP server's
    # `/mcp/live/<token>` route. Honors anything the user explicitly
    # set under `plugins.live` (metadata, serializer); only the `url`
    # is auto-injected. Skips the injection silently if the call
    # didn't arrive over a session that can receive notifications —
    # `live: true` over a stateless / non-MCP transport has nowhere
    # to send events, so we let the spawn proceed without it.
    def self.inject_live_plugin( options, instance_id:, server_context: )
        session_id = extract_session_id( server_context )
        return options if !session_id
        return options if !::Cuboid::MCP::Live.configured?

        token = ::Cuboid::MCP::Live.register(
            session_id:  session_id,
            instance_id: instance_id
        )

        options = (options || {}).dup
        # Normalise plugins to Hash{String => Hash} so the merge below
        # is well-defined regardless of whether the caller supplied
        # Hash, Array, or nothing.
        plugins = case options['plugins']
                  when Hash  then options['plugins'].dup
                  when Array then options['plugins'].each_with_object({}) { |n, h| h[n.to_s] = {} }
                  else            {}
                  end

        live_opts        = (plugins['live'] || {}).dup
        live_opts['url'] = ::Cuboid::MCP::Live.url_for( token )
        plugins['live']  = live_opts

        options['plugins'] = plugins
        options
    end

    # `MCP::ServerContext` doesn't expose its `notification_target`
    # publicly — the only readers are inside the gem. Reach through
    # to the wrapped session for its session_id; if anything in this
    # chain isn't there (stateless transport, bare invocation) we
    # bail and the live injection is skipped.
    def self.extract_session_id( server_context )
        return nil if server_context.nil?
        target = server_context.instance_variable_get( :@notification_target )
        return nil if target.nil? || !target.respond_to?( :session_id )
        target.session_id
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

                # `instance.shutdown` is an RPC call asking the engine
                # to clean up gracefully. The daemonised subprocess
                # *should* exit on its own afterwards, but in practice
                # it sometimes doesn't — leaking the ruby PID plus its
                # whole chromedriver / browser pool subtree (each
                # engine spawns ~7 chromes). Reap the PID directly
                # too: TERM, brief grace, then KILL if still around.
                pid = instance.pid rescue nil
                (instance.shutdown rescue nil)
                CoreTools.instances.delete( instance_id ).close
                # Drop any live-event registration so future engine
                # pushes 410 instead of being silently relayed.
                ::Cuboid::MCP::Live.unregister( instance_id )

                if pid && pid > 0
                    reap_engine_pid( pid )
                end

                { killed: instance_id }
            end
        end

        # Send TERM, give the engine ~2s to clean up its browser
        # cluster + temp dirs, then SIGKILL if anything's still
        # alive. Daemonised processes have no parent to wait() on, so
        # we can't reap; we just verify exit by ESRCH on `kill 0`.
        # All branches are best-effort — a missing PID, ESRCH, or
        # EPERM are all silently ignored.
        def self.reap_engine_pid( pid )
            Process.kill( 'TERM', pid ) rescue nil

            deadline = Process.clock_gettime( Process::CLOCK_MONOTONIC ) + 2.0
            while Process.clock_gettime( Process::CLOCK_MONOTONIC ) < deadline
                begin
                    Process.kill( 0, pid )
                    sleep 0.1
                rescue Errno::ESRCH
                    return
                rescue Errno::EPERM
                    return
                end
            end

            Process.kill( 'KILL', pid ) rescue nil
        end
    end

    TOOLS = [ ListInstances, SpawnInstance, KillInstance ].freeze

    def self.tools
        TOOLS
    end

end

end
end
