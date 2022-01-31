require 'cuboid/rpc/server/agent'

class Aggregator < Cuboid::RPC::Server::Agent::Service

    def foo( &block )
        aggregate( __method__, &block )
    end

    def application_access( &block )
        aggregate( __method__, &block )
    end

    private

    def aggregate( call, &block )
        each = proc do |instance, iterator|
            instance.custom.send( call ) do |data|
                iterator.return [instance.url, data]
            end
        end
        after = proc { |h| block.call Hash[h] }

        map_instances( each, after )
    end

end
