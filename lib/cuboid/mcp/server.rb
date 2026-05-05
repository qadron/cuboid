require 'puma'
require 'puma/minissl'
require 'rack'
require 'mcp'
require 'mcp/server/transports/streamable_http_transport'

require_relative 'auth'
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
                 "http#{'s' if ssl}://#{options[:bind]}:#{options[:port]}" \
                 "/instances/:instance/<service>"

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

    # Routes `/instances/:instance/<service>/...` to a per-(instance,
    # service) MCP transport. Lazily builds and caches the transport
    # on first request.
    #
    # Each transport's MCP::Server is constructed with
    # `server_context: { instance: <RPC client>, instance_id: <id> }`
    # so tool implementations can drive the engine directly:
    #
    #     def self.call(server_context:, **)
    #         server_context[:instance].scan.pause!
    #     end
    class Dispatcher
        # InstanceHelpers' @@instances class variable is shared across
        # all includers of the module — so the same map populated by
        # Rest::Server / scheduler-sync is visible here without any
        # explicit cross-process plumbing.
        include ::Cuboid::Rest::Server::InstanceHelpers

        ROUTE_RE = %r{\A/instances/(?<instance>[^/]+)/(?<service>[^/]+)(?<rest>/.*)?\z}

        def initialize( name: nil, version: nil, stateless: false )
            @name      = name
            @version   = version
            @stateless = stateless
            @transports = {}     # (instance_id, service_name) => StreamableHTTPTransport
            @mutex     = Mutex.new
        end

        def call( env )
            update_from_scheduler

            match = ROUTE_RE.match( env['PATH_INFO'].to_s )
            return not_found( 'route does not match /instances/:instance/<service>' ) if !match

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

        private

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
