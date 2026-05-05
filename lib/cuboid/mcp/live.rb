require 'json'
require 'msgpack'
require 'yaml'
require 'securerandom'

module Cuboid
module MCP

# In-process bridge between the engine's `live` plugin and the MCP
# session that asked for it. The plugin pushes JSON / msgpack / yaml
# envelopes to `/mcp/live/<token>` (loopback) and we relay each one
# back to the originating MCP session as a custom JSON-RPC
# notification (`notifications/<brand>/live` — the `<brand>` segment
# is derived from the running `Cuboid::Application`'s top-level
# namespace `shortname`, matching what `serverInfo` advertises). One
# token per spawned instance; dropped on `kill_instance` or when the
# session goes away.
#
# Singleton state because the dispatcher / SpawnInstance core tool /
# the live POST handler all need to reach the same registry without
# threading a reference through everything.
module Live

    # Decoders keyed by Content-Type substring.
    DECODERS = {
        'msgpack' => ->( raw ) { MessagePack.unpack( raw ) },
        'yaml'    => ->( raw ) { ::YAML.safe_load( raw, permitted_classes: [Symbol, Time] ) || {} },
        'json'    => ->( raw ) { ::JSON.parse( raw ) }
    }.freeze

    @mutex     = Mutex.new
    @bind      = nil
    @port      = nil
    @scheme    = 'http'
    @transport = nil
    # token => { session_id:, instance_id: }
    @by_token       = {}
    # instance_id => token (for cleanup on kill_instance)
    @by_instance_id = {}

    class <<self

        # JSON-RPC notification method clients should subscribe to.
        # Brand-derived from the running `Cuboid::Application` so
        # different products built on cuboid get distinct
        # namespaces — an application with `shortname == :foo`
        # produces `notifications/foo/live`. Falls back to
        # `notifications/cuboid/live` when no application is
        # registered (bare framework / specs).
        def notification_method
            "notifications/#{brand_segment}/live"
        end

        def brand_segment
            app = ::Cuboid::Application.application
            return 'cuboid' if app.nil?
            ns = app.name.to_s.split( '::' ).first
            return 'cuboid' if ns.nil? || ns.empty?
            mod = Object.const_get( ns )
            (mod.respond_to?( :shortname ) ? mod.shortname : ns).to_s
        rescue
            'cuboid'
        end

        # Called from `Server.run!` once the listener is bound so
        # `url_for(token)` can synthesise a loopback URL the engine
        # subprocess will POST to.
        def configure( bind:, port:, tls: false )
            @mutex.synchronize do
                @bind   = bind
                @port   = port
                @scheme = tls ? 'https' : 'http'
            end
        end

        def configured?
            @mutex.synchronize { !!(@bind && @port) }
        end

        # Stored once the dispatcher builds the MCP::Server transport.
        # We use it to dispatch `notifications/cuboid/live` to the
        # session that owns each live token.
        def transport=( t )
            @mutex.synchronize { @transport = t }
        end

        # Register a fresh live token bound to this MCP session +
        # engine instance pair. Returns the token. Idempotent per
        # instance — re-registering replaces any prior token.
        def register( session_id:, instance_id: )
            token = SecureRandom.uuid
            @mutex.synchronize do
                # Drop any prior token for this instance — stale entries
                # would leak the registry indefinitely under the rare
                # case of double-spawn for the same instance_id.
                if (prev = @by_instance_id[instance_id])
                    @by_token.delete( prev )
                end
                @by_token[token]               = { session_id: session_id, instance_id: instance_id }
                @by_instance_id[instance_id]   = token
            end
            token
        end

        # Drop the registration for an instance (called from
        # `kill_instance`). No-op if there's nothing registered.
        def unregister( instance_id )
            @mutex.synchronize do
                token = @by_instance_id.delete( instance_id )
                @by_token.delete( token ) if token
            end
        end

        # Loopback URL the engine subprocess pushes to. The engine
        # is forked on the same host so loopback is always reachable.
        def url_for( token )
            @mutex.synchronize do
                fail 'Live#configure has not been called' if !@bind || !@port
                "#{@scheme}://#{@bind}:#{@port}/mcp/live/#{token}"
            end
        end

        # Forward a decoded envelope from the engine push to the
        # originating MCP session as `notifications/cuboid/live`.
        # Returns true on success, false when the token is unknown
        # or the transport hasn't been wired yet (caller maps these
        # to 404 / 410 / 503).
        def deliver( token, envelope )
            registration, transport = nil, nil

            @mutex.synchronize do
                registration = @by_token[token]
                transport    = @transport
            end

            return false if !registration || !transport

            params = envelope.is_a?( Hash ) ? envelope : { 'envelope' => envelope }
            params = params.merge( 'instance_id' => registration[:instance_id] )

            transport.send_notification(
                notification_method,
                params,
                session_id: registration[:session_id]
            )
            true
        rescue => e
            warn "[Cuboid::MCP::Live] deliver failed: #{e.class}: #{e.message}"
            false
        end

        # Decode a Rack request body using its `Content-Type` header.
        # Falls back to JSON; raises on undecipherable input so the
        # caller can return 400.
        def decode( content_type, body )
            content_type = content_type.to_s
            decoder = DECODERS.find { |fmt, _| content_type.include?( fmt ) }&.last
            decoder ||= DECODERS['json']
            decoder.call( body )
        end

    end

end
end
end
