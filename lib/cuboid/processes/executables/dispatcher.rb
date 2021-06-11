require Options.paths.lib  + 'rpc/server/dispatcher'

Arachni::Reactor.global.run do
    RPC::Server::Dispatcher.new
end
