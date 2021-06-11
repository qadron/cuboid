require Options.paths.lib  + 'rpc/server/scheduler'

Arachni::Reactor.global.run do
    RPC::Server::Scheduler.new
end
