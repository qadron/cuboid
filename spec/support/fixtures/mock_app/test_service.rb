require 'cuboid/rpc/server/dispatcher'

class TestService < Cuboid::RPC::Server::Dispatcher::Service

    private :instances
    public  :instances

    def test_dispatcher
        dispatcher.class == Cuboid::RPC::Server::Dispatcher
    end

    def test_opts
        dispatcher.instance_eval{ @options } == options
    end

    def test_node
        node.class == Cuboid::RPC::Server::Dispatcher::Node
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

    def test_connect_to_dispatcher( url, &block )
        connect_to_dispatcher( url ).alive? { |b| block.call b }
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
