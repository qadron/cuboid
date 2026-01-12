require_relative 'server'

opts = rpc_opts.merge(
    socket:     '/tmp/toq-rpc-test',
    serializer: Marshal
)

start_server( opts )
