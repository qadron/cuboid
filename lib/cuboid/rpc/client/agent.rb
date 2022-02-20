module Cuboid

require Options.paths.lib + 'rpc/client/base'

module RPC
class Client

# RPC Agent client
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Agent
    # Not always available, set by the parent.
    attr_accessor :pid

    attr_reader :node

    def initialize( url, options = nil )
        @client = Base.new( url, nil, options )
        @node   = Toq::Proxy.new( @client, 'node' )

        Cuboid::Application.application.agent_services.keys.each do |name|
            self.class.send( :attr_reader, name.to_sym )

            instance_variable_set(
              "@#{name}".to_sym,
              Toq::Proxy.new( @client, name )
            )
        end
    end

    def url
        @client.url
    end

    def address
        @client.address
    end

    def port
        @client.port
    end

    def close
        @client.close
    end

    private

    # Used to provide the illusion of locality for remote methods
    def method_missing( sym, *args, &block )
        @client.call( "agent.#{sym.to_s}", *args, &block )
    end

end

end
end
end
