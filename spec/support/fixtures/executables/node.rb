require Options.paths.lib + 'ui/output'
require Options.paths.lib + 'rpc/server/agent'
require Options.paths.lib + 'processes/manager'

class Node < Cuboid::RPC::Server::Agent::Node

    def initialize
        @options = Options.instance

        methods.each do |m|
            next if method( m ).owner != Cuboid::RPC::Server::Agent::Node
            self.class.send :private, m
            self.class.send :public, m
        end

        @server = Cuboid::RPC::Server::Base.new
        @server.add_async_check do |method|
            # methods that expect a block are async
            method.parameters.flatten.include?( :block )
        end
        @server.add_handler( 'node', self )

        super @options, @server

        @server.start
    end

    def url
        @server.url
    end

    def shutdown
        Raktr.global.delay 1 do
            Process.kill( 'KILL', Process.pid )
        end
    end

    def connect_to_peer( url )
        self.class.connect_to_peer( url )
    end

    def self.connect_to_peer( url )
        c = Cuboid::RPC::Client::Base.new( url )
        Toq::Proxy.new( c, 'node' )
    end
end

Raktr.global.run do
    Node.new
end
