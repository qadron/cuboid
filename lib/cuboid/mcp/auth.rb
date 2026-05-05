require 'json'

module Cuboid
module MCP

# Bearer-token authentication middleware for the MCP transport.
#
# Application gems opt in by registering a validator block on their
# Cuboid::Application subclass:
#
#     class MyApplication < Cuboid::Application
#         mcp_authenticate_with do |token|
#             # Return truthy (typically the User record) on success,
#             # nil/false on failure.
#             User.find_by( api_token: token )
#         end
#     end
#
# When no validator is registered the middleware passes every request
# through — useful for smoke tests and for transports terminated
# behind another auth layer (e.g. a reverse proxy).
#
# On success the resolved validator return value is stashed in
# `env['cuboid.mcp.auth']` so downstream middleware / tooling can
# look up the authenticated principal.
#
# Failure modes follow RFC 6750 — Bearer Token Usage:
#   * Missing / malformed Authorization header → 401 + WWW-Authenticate
#   * Token rejected by the validator           → 401 + WWW-Authenticate
class Auth

    REALM = 'MCP'.freeze

    # Standard Bearer-prefix per RFC 6750 §2.1, case-insensitive.
    BEARER_PREFIX = /\ABearer\s+/i

    def initialize( app )
        @app = app
    end

    def call( env )
        validator = current_validator
        return @app.call( env ) if validator.nil?

        token = extract_token( env )
        return unauthorized( 'invalid_request' )      if token.nil?

        principal = safe_validate( validator, token )
        return unauthorized( 'invalid_token' )        if !principal

        env['cuboid.mcp.auth'] = principal
        @app.call( env )
    end

    private

    # Look up the validator at request time (not boot time) so
    # applications can register / replace it after the server has
    # already booted.
    def current_validator
        app = ::Cuboid::Application.application
        return nil if app.nil?
        return nil if !app.respond_to?( :mcp_auth_validator )
        app.mcp_auth_validator
    end

    def extract_token( env )
        header = env['HTTP_AUTHORIZATION'].to_s
        return nil if header.empty?
        return nil if header !~ BEARER_PREFIX
        header.sub( BEARER_PREFIX, '' ).strip
    end

    # Wrap the validator call so an exception in user code becomes a
    # generic 401 rather than a 500 — leaking validator internals to
    # an unauthenticated caller would be a footgun.
    def safe_validate( validator, token )
        validator.call( token )
    rescue => e
        warn "[Cuboid::MCP::Auth] validator raised: #{e.class}: #{e.message}"
        nil
    end

    def unauthorized( error )
        body = { jsonrpc: '2.0', error: { code: -32001, message: error } }.to_json
        [
            401,
            {
                'content-type'     => 'application/json',
                'www-authenticate' => %(Bearer realm="#{REALM}", error="#{error}")
            },
            [body]
        ]
    end

end

end
end
