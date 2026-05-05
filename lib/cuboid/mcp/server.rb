require 'puma'
require 'puma/minissl'
require 'rack'
require 'mcp'
require 'mcp/server/transports/streamable_http_transport'

# json-schema (a transitive dep of `mcp` for MCP::Tool input/output
# schema validation) emits a one-time deprecation notice at first use
# unless we opt out of its MultiJson backend. Stdlib JSON is faster
# and already loaded — no reason to keep MultiJson in the chain.
require 'json-schema'
JSON::Validator.use_multi_json = false

require_relative 'auth'
require_relative 'core_tools'
require_relative '../rest/server/instance_helpers'

module Cuboid
module MCP

# Cuboid's MCP-server framework. Mirrors `Cuboid::Rest::Server`:
# application gems register tool handlers via `mcp_service_for(name,
# handler)` on their `Cuboid::Application` subclass; this server
# mounts one MCP transport per (instance, service) pair under
# `/instances/:instance/<service>` and proxies tool calls to the
# resolved engine instance via RPC.
#
# Spawnable as `:mcp` via Cuboid::Processes::Manager (see
# `lib/cuboid/processes/executables/mcp.rb`).
class Server

    class << self

        # Boot the MCP server.
        #
        # @param [Hash] options
        # @option options [String]  :bind     IP/host to bind
        # @option options [Integer] :port     Port to listen on
        # @option options [String]  :name     MCP server name advertised to clients
        # @option options [String]  :version  MCP server version advertised to clients
        # @option options [Hash]    :tls      Optional TLS — same shape as Rest::Server
        # @option options [Boolean] :stateless  Streamable HTTP stateless mode
        def run!( options )
            puma = Puma::Server.new( rack_app( options ) )

            ssl = configure_listener( puma, options )

            puts "MCP server listening on " \
                 "http#{'s' if ssl}://#{options[:bind]}:#{options[:port]}\n" \
                 "  /mcp                              — framework tools (spawn / list / kill)\n" \
                 "  /instances/:instance/<service>    — application tools per running instance"

            begin
                puma.run.join
            rescue Interrupt
                puma.stop( true )
            end
        end

        # Build (without booting) the Rack app — exposed for tests
        # (Rack::Test against `rack_app({})`) and for embedders that
        # want to mount MCP under a larger Rack tree.
        def rack_app( options = {} )
            dispatcher = Dispatcher.new(
                name:      options[:name],
                version:   options[:version],
                stateless: options.fetch( :stateless, false )
            )

            Rack::Builder.new do
                use Cuboid::MCP::Auth
                run dispatcher
            end.to_app
        end

        private

        def configure_listener( puma_server, options )
            tls = options[:tls]

            if tls && tls[:private_key] && tls[:certificate]
                ctx = Puma::MiniSSL::Context.new
                ctx.key  = tls[:private_key]
                ctx.cert = tls[:certificate]

                if tls[:ca]
                    puts 'CA provided, peer verification enabled.'
                    ctx.ca          = tls[:ca]
                    ctx.verify_mode = Puma::MiniSSL::VERIFY_PEER |
                                       Puma::MiniSSL::VERIFY_FAIL_IF_NO_PEER_CERT
                else
                    puts 'CA missing, peer verification disabled.'
                end

                puma_server.binder.add_ssl_listener(
                    options[:bind], options[:port], ctx
                )
                true
            else
                puma_server.add_tcp_listener( options[:bind], options[:port] )
                false
            end
        end

    end

    # Routes incoming MCP requests to one of two transports:
    #
    #   /mcp                            → framework tools (spawn /
    #                                     list / kill instances). Cuboid
    #                                     ships these directly via
    #                                     `Cuboid::MCP::CoreTools`.
    #
    #   /instances/:instance/<service>  → application tools registered
    #                                     via `mcp_service_for` on the
    #                                     Cuboid::Application subclass,
    #                                     scoped to one running engine
    #                                     instance.
    #
    # Per-instance per-service transports are lazily built and cached
    # on first request; the core /mcp transport is built once at boot.
    # Each per-instance MCP::Server gets
    # `server_context: { instance: <RPC client>, instance_id: <id>, service: <sym> }`
    # so tool implementations can drive the application instance directly:
    #
    #     def self.call(server_context:, **)
    #         server_context[:instance].some_application_method
    #     end
    class Dispatcher
        # InstanceHelpers' @@instances class variable is shared across
        # all includers of the module — so the same map populated by
        # Rest::Server / scheduler-sync / our own SpawnInstance core
        # tool is visible here without any explicit cross-process
        # plumbing.
        include ::Cuboid::Rest::Server::InstanceHelpers

        CORE_PATH         = '/mcp'.freeze
        PER_INSTANCE_RE   = %r{\A/instances/(?<instance>[^/]+)/(?<service>[^/]+)(?<rest>/.*)?\z}
        CORE_PATH_RE      = %r{\A/mcp(?<rest>/.*)?\z}

        def initialize( name: nil, version: nil, stateless: false )
            @name      = name
            @version   = version
            @stateless = stateless
            @transports = {}     # (instance_id, service_name) => StreamableHTTPTransport
            @mutex     = Mutex.new
        end

        def call( env )
            update_from_scheduler

            path = env['PATH_INFO'].to_s

            if (m = CORE_PATH_RE.match( path ))
                dispatch_core( env, m )
            elsif (m = PER_INSTANCE_RE.match( path ))
                dispatch_per_instance( env, m )
            else
                not_found( 'route does not match /mcp or /instances/:instance/<service>' )
            end
        end

        private

        def dispatch_core( env, match )
            sub_env = env.dup
            sub_env['PATH_INFO']   = match[:rest].to_s
            sub_env['SCRIPT_NAME'] = "#{env['SCRIPT_NAME']}/mcp"
            core_transport.call( sub_env )
        end

        def dispatch_per_instance( env, match )
            instance_id  = match[:instance]
            service_name = match[:service].to_sym

            handler = mcp_services[service_name]
            return not_found( "unknown MCP service: #{service_name.inspect}" ) if !handler

            instance = instances[instance_id]
            return not_found( "unknown instance: #{instance_id.inspect}" ) if !instance

            transport = transport_for( instance_id, service_name, handler, instance )

            # Strip the /instances/:instance/<service> prefix so the
            # transport sees only the trailing path it owns (Streamable
            # HTTP routes by REQUEST_METHOD; PATH_INFO is just used for
            # session-id check on subsequent requests, but we keep
            # SCRIPT_NAME accurate for any future per-mount logic).
            sub_env = env.dup
            sub_env['PATH_INFO']   = match[:rest].to_s
            sub_env['SCRIPT_NAME'] = "#{env['SCRIPT_NAME']}/instances/#{instance_id}/#{service_name}"

            transport.call( sub_env )
        end

        def core_transport
            @core_transport ||= begin
                mcp_server = ::MCP::Server.new(
                    name:    @name    || 'cuboid',
                    version: @version || ::Cuboid::VERSION,
                    tools:   ::Cuboid::MCP::CoreTools.tools
                )
                ::MCP::Server::Transports::StreamableHTTPTransport.new(
                    mcp_server,
                    stateless: @stateless
                )
            end
        end

        def mcp_services
            app = ::Cuboid::Application.application
            return {} if app.nil?
            return {} if !app.respond_to?( :mcp_services )
            app.mcp_services
        end

        def transport_for( instance_id, service_name, handler, instance )
            tools = Array( handler.tools )

            @mutex.synchronize do
                @transports[[instance_id, service_name]] ||= begin
                    mcp_server = ::MCP::Server.new(
                        name:    @name    || "cuboid-#{service_name}",
                        version: @version || ::Cuboid::VERSION,
                        tools:   tools,
                        server_context: {
                            instance:    instance,
                            instance_id: instance_id,
                            service:     service_name
                        }
                    )

                    ::MCP::Server::Transports::StreamableHTTPTransport.new(
                        mcp_server,
                        stateless: @stateless
                    )
                end
            end
        end

        def not_found( message )
            body = { jsonrpc: '2.0', error: { code: -32601, message: message } }.to_json
            [ 404, { 'content-type' => 'application/json' }, [body] ]
        end
    end

end

end
end
