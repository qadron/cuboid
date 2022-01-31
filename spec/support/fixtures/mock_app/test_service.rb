require 'cuboid/rpc/server/agent'

class TestService < Cuboid::RPC::Server::Agent::Service

    private :instances
    public  :instances

    def test_agent
        agent.class == Cuboid::RPC::Server::Agent
    end

    def test_opts
        agent.instance_eval{ @options } == options
    end

    def test_node
        node.class == Cuboid::RPC::Server::Agent::Node
    end

    def test_map_instances( &block )
        each = proc do |instance, iterator|
            iterator.return [instance.url, instance.token]
        end
        after = proc { |i| block.call Hash[i] }

        map_instances( each, after )
    end

    def test_each_instance
        i = 0
        each_instance do |instance, iterator|
            i += 1
            instance.options.set( authorized_by: "test_#{i}@test.com") { |p| iterator.next }
        end
        true
    end

    def test_iterator_for
        iterator_for( instances ).class == Arachni::Reactor::Iterator
    end

    def test_connect_to_agent( url, &block )
        connect_to_agent( url ).alive? { |b| block.call b }
    end

    def test_connect_to_instance( *args, &block )
        connect_to_instance( *args ).busy?{ |b| block.call !!b }
    end

    def test_defer( *args, &block )
        defer do
            block.call args
        end
    end

    def test_run_asap( *args, &block )
        run_asap { block.call args }
    end

    def echo( *args )
        args
    end

end
