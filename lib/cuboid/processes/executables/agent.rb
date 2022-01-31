require Options.paths.lib  + 'rpc/server/agent'

Arachni::Reactor.global.run do
    RPC::Server::Agent.new
end
