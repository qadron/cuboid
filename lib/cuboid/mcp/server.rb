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
require_relative 'live'
require_relative '../server/instance_helpers'

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

            # Configure the Live registry so its `url_for(token)` can
            # synthesise the loopback URL the engine subprocess will
            # POST live events to. Done after listener configuration so
            # we know the resolved scheme.
            Live.configure(
                bind: options[:bind],
                port: options[:port],
                tls:  ssl
            )

            puts "MCP server listening on " \
                 "http#{'s' if ssl}://#{options[:bind]}:#{options[:port]}/mcp"

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

    # Mounts a single MCP transport at `/mcp`. Tools are flattened into
    # one server:
    #
    #   * Framework tools (`list_instances`, `spawn_instance`,
    #     `kill_instance`) ship from `Cuboid::MCP::CoreTools`.
    #   * Application service tools registered via `mcp_service_for` on
    #     the `Cuboid::Application` subclass are wrapped to take an
    #     `instance_id` argument and are exposed under
    #     `<service>_<original_tool_name>` (e.g. `scan_progress`).
    #
    # The wrapper resolves `instance_id` against the shared instance
    # map at call time and forwards the looked-up RPC client to the
    # original tool via `server_context[:instance]` — so existing
    # `MCPProxy.instrumented_call(server_context) { |instance| … }` code
    # works unchanged.
    #
    # Earlier revisions exposed a `/instances/:instance/<service>`
    # second route; that's gone. One endpoint, one session, no
    # runtime URL handoff to the client.
    class Dispatcher
        # InstanceHelpers' @@instances class variable is shared across
        # all includers of the module — so the same map populated by
        # Rest::Server / scheduler-sync / our own SpawnInstance core
        # tool is visible here without any explicit cross-process
        # plumbing.
        include ::Cuboid::Server::InstanceHelpers

        # `/mcp/live/<token>` matches BEFORE `/mcp` would swallow it
        # in the regex chain — order checks accordingly in `call`.
        LIVE_PATH_RE = %r{\A/mcp/live/(?<token>[A-Za-z0-9_-]+)/?\z}
        MCP_PATH_RE  = %r{\A/mcp(?<rest>/.*)?\z}

        def initialize( name: nil, version: nil, stateless: false )
            @name      = name
            @version   = version
            @stateless = stateless
            @mutex     = Mutex.new
        end

        def call( env )
            update_from_scheduler

            path = env['PATH_INFO'].to_s

            if (m = LIVE_PATH_RE.match( path ))
                handle_live_push( env, m[:token] )
            elsif (m = MCP_PATH_RE.match( path ))
                sub_env = env.dup
                sub_env['PATH_INFO']   = m[:rest].to_s
                sub_env['SCRIPT_NAME'] = "#{env['SCRIPT_NAME']}/mcp"
                transport.call( sub_env )
            else
                not_found( 'route does not match /mcp or /mcp/live/<token>' )
            end
        end

        # Forward a single engine-side push (msgpack/json/yaml body) to
        # the MCP session that registered the token. Loopback-only:
        # the engine subprocess pushes from the same host, never from
        # an external network. No auth — the token is the auth.
        def handle_live_push( env, token )
            remote = env['REMOTE_ADDR'].to_s
            unless %w(127.0.0.1 ::1 ::ffff:127.0.0.1).include?( remote )
                return not_found( 'live push must come from loopback' )
            end

            # Drain Rack's input. Rack 3 may have already consumed it
            # for known content types; rewind defensively.
            input = env['rack.input']
            input.rewind if input.respond_to?( :rewind )
            body = input.read

            envelope =
                begin
                    Live.decode( env['CONTENT_TYPE'], body )
                rescue => e
                    return [ 400, { 'content-type' => 'application/json' },
                             [ { error: "could not decode #{env['CONTENT_TYPE']}: #{e.class}" }.to_json ] ]
                end

            ok = Live.deliver( token, envelope )
            return [ 410, { 'content-type' => 'application/json' },
                     [ { error: 'live token unknown or session gone' }.to_json ] ] if !ok

            [ 204, {}, [] ]
        end

        private

        def transport
            @mutex.synchronize do
                @transport ||= begin
                    mcp_server = ::MCP::Server.new(
                        name:      @name    || application_brand_name    || 'cuboid',
                        version:   @version || application_brand_version || ::Cuboid::VERSION,
                        tools:     build_tools,
                        prompts:   build_prompts,
                        resources: build_resources
                    )

                    if (read_handler = build_resources_read_handler)
                        mcp_server.resources_read_handler( &read_handler )
                    end

                    t = ::MCP::Server::Transports::StreamableHTTPTransport.new(
                        mcp_server,
                        stateless: @stateless
                    )

                    # Hand the transport to Live so `/mcp/live/<token>`
                    # pushes can be relayed to the right session as
                    # `notifications/cuboid/live` notifications.
                    Live.transport = t

                    t
                end
            end
        end

        def build_tools
            tools = ::Cuboid::MCP::CoreTools.tools.dup

            # App-level top-level tools registered via
            # `Cuboid::Application.mcp_app_tool` — ride the same
            # routing as CoreTools (no instance_id requirement).
            app = ::Cuboid::Application.application
            if app.respond_to?( :mcp_app_tools )
                tools.concat( app.mcp_app_tools )
            end

            mcp_services.each do |service_name, handler|
                Array( handler.tools ).each do |tool_class|
                    tools << Dispatcher.wrap_service_tool( service_name, tool_class )
                end
            end

            tools
        end

        # Application MCP-service handlers may optionally expose
        # `prompts` (canned conversation templates the client can
        # surface to a user — e.g. "scan this URL with the quick-scan
        # preset and summarise findings") and `resources` (read-only
        # documents — glossary, option DSL reference, presets — that
        # an LLM client pulls on demand instead of needing them
        # bundled into every tool description).
        #
        # Both are additive: a handler that doesn't define `prompts` /
        # `resources` is silently treated as exposing none.
        def build_prompts
            mcp_services.values.flat_map do |handler|
                handler.respond_to?( :prompts ) ? Array( handler.prompts ) : []
            end
        end

        def build_resources
            mcp_services.values.flat_map do |handler|
                handler.respond_to?( :resources ) ? Array( handler.resources ) : []
            end
        end

        # Returns a Proc the MCP::Server uses for `resources/read`. The
        # proc walks every handler that implements `read_resource(uri)`
        # and returns the first non-nil match, normalised to the
        # `Array<Resource::Contents-as-Hash>` shape the spec expects.
        # Nil if no handler implements the protocol — letting the
        # gem's default no-content responder do its thing.
        def build_resources_read_handler
            handlers = mcp_services.values.select { |h| h.respond_to?( :read_resource ) }
            return nil if handlers.empty?

            ->( params ) {
                uri = params[:uri].to_s
                handlers.each do |h|
                    content = h.read_resource( uri )
                    next if content.nil?
                    return Array( content ).map { |c|
                        c.respond_to?( :to_h ) ? c.to_h : c
                    }
                end
                []
            }
        end

        # Wraps an application-supplied `MCP::Tool` subclass so it can
        # live in the unified `/mcp` server. The wrapper:
        #
        #   * exposes `<service>_<original_tool_name>` as its name
        #   * augments the input schema with a required `instance_id`
        #     string (the only piece the client must supply that the
        #     old per-instance routing carried in the URL)
        #   * resolves `instance_id` to a registered RPC client at call
        #     time and hands it to the wrapped tool via
        #     `server_context[:instance]` — preserving the original
        #     `instrumented_call(server_context) { |instance| … }`
        #     contract.
        #
        # Class method (not instance) so the registry that owns the
        # wrapper class doesn't carry hidden state across requests.
        def self.wrap_service_tool( service_name, tool_class )
            base_schema  = tool_class.input_schema.to_h
            base_props   = base_schema[:properties] || {}
            base_required = (base_schema[:required] || []).map( &:to_s )

            new_props = base_props.merge(
                instance_id: {
                    type:        'string',
                    description: 'Engine-instance handle returned by `spawn_instance` / present in `list_instances`.'
                }
            )
            new_required = (base_required + ['instance_id']).uniq

            wrapped_name = "#{service_name}_#{tool_class.tool_name}"
            wrapped_desc = tool_class.description

            klass = Class.new( ::MCP::Tool )
            klass.tool_name    wrapped_name
            klass.description  wrapped_desc
            klass.input_schema(
                properties: new_props,
                required:   new_required
            )

            # Pass the original tool's output_schema through to the
            # wrapper so a typed-output client sees the same contract
            # whether the tool ships from CoreTools or from a service.
            if (out = tool_class.output_schema_value)
                klass.output_schema( out.to_h )
            end

            klass.define_singleton_method( :call ) do |server_context: nil, instance_id: nil, **kwargs|
                instance = ::Cuboid::Server::InstanceHelpers
                    .instances[instance_id]
                if instance.nil?
                    next ::MCP::Tool::Response.new(
                        [{ type: 'text', text: "unknown instance: #{instance_id.inspect}" }],
                        error: true
                    )
                end

                # MCPProxy reads `server_context[:instance]` etc. via
                # Hash-style access, which `MCP::ServerContext` forwards
                # to the underlying context Hash via method_missing —
                # so passing a plain Hash here keeps the proxy contract.
                ctx = {
                    instance:    instance,
                    instance_id: instance_id,
                    service:     service_name
                }

                tool_class.call( server_context: ctx, **kwargs )
            end

            klass
        end

        def mcp_services
            app = ::Cuboid::Application.application
            return {} if app.nil?
            return {} if !app.respond_to?( :mcp_services )
            app.mcp_services
        end

        # Identity advertised in MCP `serverInfo` defaults to the running
        # Cuboid::Application's top-level namespace — preferring its
        # branded `shortname` / `version` methods over the raw module
        # name + VERSION constant. Falls back to 'cuboid' /
        # Cuboid::VERSION when no application is registered (bare
        # framework / specs). Explicit `name:` / `version:` passed to
        # `run!` always win.
        def application_brand
            return @application_brand if defined?( @application_brand )

            app = ::Cuboid::Application.application
            @application_brand =
                if app && (ns = app.name.to_s.split( '::' ).first) && !ns.empty?
                    mod = Object.const_get( ns )

                    name =
                        if mod.respond_to?( :shortname )
                            mod.shortname.to_s
                        else
                            ns
                        end

                    version =
                        if mod.respond_to?( :version )
                            mod.version.to_s
                        elsif mod.const_defined?( :VERSION )
                            mod::VERSION
                        end

                    { name: name, version: version }
                else
                    { name: nil, version: nil }
                end
        end

        def application_brand_name;    application_brand[:name];    end
        def application_brand_version; application_brand[:version]; end

        def not_found( message )
            body = { jsonrpc: '2.0', error: { code: -32601, message: message } }.to_json
            [ 404, { 'content-type' => 'application/json' }, [body] ]
        end
    end

end

end
end
