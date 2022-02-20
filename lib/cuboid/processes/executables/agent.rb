require Options.paths.lib  + 'rpc/server/agent'

Raktr.global.run do
    RPC::Server::Agent.new
end
