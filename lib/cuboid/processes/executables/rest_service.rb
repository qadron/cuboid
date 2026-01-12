require Options.paths.lib  + 'rest/server'

Rest::Server.run!(
    port:     Options.rpc.server_port,
    bind:     Options.rpc.server_address,

    username: Options.datastore['username'],
    password: Options.datastore['password'],

    tls: {
      ca:          Options.rpc.ssl_ca,
      private_key: Options.rpc.server_ssl_private_key,
      certificate: Options.rpc.server_ssl_certificate
    }
)
