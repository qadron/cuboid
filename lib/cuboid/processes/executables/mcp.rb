# Spawnable as `:mcp` via Cuboid::Processes::Manager — mirror of
# `executables/rest_service.rb`. Boots Cuboid::MCP::Server on the
# RPC-port/address from Cuboid::Options so the operator can spawn an
# MCP server alongside REST/agent/scheduler with the same option
# plumbing.
require Options.paths.lib + 'mcp/server'

# Fully qualified — the `mcp` gem also exposes a top-level `MCP::Server`
# (different class entirely), and `include Cuboid` in executables/base.rb
# would otherwise hide that disambiguation.
Cuboid::MCP::Server.run!(
    bind: Options.rpc.server_address,
    port: Options.rpc.server_port,

    tls: {
        ca:          Options.rpc.ssl_ca,
        private_key: Options.rpc.server_ssl_private_key,
        certificate: Options.rpc.server_ssl_certificate
    }
)
