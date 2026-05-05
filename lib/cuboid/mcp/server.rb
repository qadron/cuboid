require 'puma'
require 'puma/minissl'
require 'rack'
require 'mcp'
require 'mcp/server/transports/streamable_http_transport'

require_relative 'auth'

module Cuboid
module MCP

# Cuboid's MCP-server framework. Application gems register tools (a
# class-per-tool subclassing `MCP::Tool`) via `mcp_tool_for` on their
# `Cuboid::Application` subclass. This wrapper boots an MCP::Server
# with those tools and mounts its `StreamableHTTPTransport` (POST for
# JSON-RPC requests, GET for the SSE stream) on a Puma listener.
#
# Mirrors the shape of `Cuboid::Rest::Server` so consumers have a
# consistent boot story across the two surfaces.
class Server

    # MCP transport's HTTP path. Single endpoint that accepts POST
    # (JSON-RPC requests) and GET (SSE stream); the transport's
    # Rack-level dispatcher routes by request method.
    DEFAULT_PATH = '/mcp'.freeze

    class << self

        # Boot the MCP server.
        #
        # @param [Hash] options
        # @option options [String]  :bind     IP/host to bind ('0.0.0.0', '127.0.0.1', etc.)
        # @option options [Integer] :port     Port to listen on
        # @option options [String]  :path     Mount path (default: '/mcp')
        # @option options [String]  :name     Server name advertised to clients
        # @option options [String]  :version  Server version advertised to clients
        # @option options [Hash]    :tls      Optional TLS settings —
        #   { private_key:, certificate:, ca: } — same shape as
        #   Cuboid::Rest::Server.
        # @option options [Boolean] :stateless  Stateless mode for the
        #   StreamableHTTPTransport (no per-session state). Default: false.
        def run!( options )
            mcp_server = build_mcp_server( options )

            transport = ::MCP::Server::Transports::StreamableHTTPTransport.new(
                mcp_server,
                stateless: options.fetch( :stateless, false )
            )

            rack_app = build_rack_app( transport, options )

            puma_server = Puma::Server.new( rack_app )

            ssl = configure_listener( puma_server, options )

            puts "MCP server listening on " \
                 "http#{'s' if ssl}://#{options[:bind]}:#{options[:port]}" \
                 "#{options[:path] || DEFAULT_PATH}"

            begin
                puma_server.run.join
            rescue Interrupt
                puma_server.stop( true )
            end
        end

        private

        def build_mcp_server( options )
            ::MCP::Server.new(
                name:    options[:name]    || application_name,
                version: options[:version] || ::Cuboid::VERSION,
                tools:   registered_tools
            )
        end

        # Tools come from whichever Cuboid::Application subclass the
        # consumer registered. Returns [] when nothing has been
        # registered — the server still boots and just advertises an
        # empty tool list, which is useful for smoke tests.
        def registered_tools
            app = ::Cuboid::Application.application
            return [] if app.nil?
            return [] if !app.respond_to?( :mcp_tools )
            app.mcp_tools
        end

        def application_name
            app = ::Cuboid::Application.application
            return 'cuboid' if app.nil?
            app.to_s.downcase.gsub( '::', '-' )
        end

        # Wrap the transport in a Rack::Builder so route mounting + any
        # pre-transport middleware (auth, logging, request-id, …) live
        # in one place. Auth is opt-in — applications register a
        # validator via `mcp_authenticate_with` on their
        # `Cuboid::Application` subclass; without one the middleware
        # passes every request through.
        def build_rack_app( transport, options )
            path = options[:path] || DEFAULT_PATH
            Rack::Builder.new do
                use Cuboid::MCP::Auth
                map( path ) { run transport }
            end.to_app
        end

        # Same TLS handling as Cuboid::Rest::Server — Puma's MiniSSL
        # context for cert/key/ca, optional client-cert verification.
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

end

end
end
