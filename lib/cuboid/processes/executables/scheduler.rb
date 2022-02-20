require Options.paths.lib  + 'rpc/server/scheduler'

Raktr.global.run do
    RPC::Server::Scheduler.new
end
