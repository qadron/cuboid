module Cuboid
module RPC

# Base class and namespace for all Agent services.
#
# # RPC accessibility
#
# Only PUBLIC methods YOU have defined will be accessible over RPC.
#
# # Blocking operations
#
# Please try to avoid blocking operations as they will block the main Reactor loop.
#
# However, if you really need to perform such operations, you can update the
# relevant methods to expect a block and then pass the desired return value to
# that block instead of returning it the usual way.
#
# This will result in the method's payload to be deferred into a Thread of its own.
#
# In addition, you can use the {#defer} and {#run_asap} methods is you need more
# control over what gets deferred and general scheduling.
#
# # Asynchronous operations
#
# Methods which perform async operations should expect a block and pass their
# results to that block instead of returning a value.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Server::Agent::Service

    attr_reader :options
    attr_reader :agent

    def initialize( options, agent )
        @options    = options
        @agent = agent
    end

    # @return   [Server::Agent::Node]
    #   Local node.
    def node
        agent.instance_eval { @node }
    end

    # Performs an asynchronous map operation over all running instances.
    #
    # @param [Proc]  each
    #   Block to be passed {Client::Instance} and `Arachni::Reactor::Iterator`.
    # @param [Proc]  after
    #   Block to be passed the Array of results.
    def map_instances( each, after )
        wrap_each = proc do |instance, iterator|
            each.call( connect_to_instance( instance ), iterator )
        end
        iterator_for( instances ).map( wrap_each, after )
    end

    # Performs an asynchronous iteration over all running instances.
    #
    # @param [Proc]  block
    #   Block to be passed {Client::Instance} and `Arachni::Reactor::Iterator`.
    def each_instance( &block )
        wrap = proc do |instance, iterator|
            block.call( connect_to_instance( instance ), iterator )
        end
        iterator_for( instances ).each( &wrap )
    end

    # Defers a blocking operation in order to avoid blocking the main Reactor loop.
    #
    # The operation will be run in its own Thread - DO NOT block forever.
    #
    # Accepts either 2 parameters (an `operation` and a `callback` or an operation
    # as a block.
    #
    # @param    [Proc]  operation
    #   Operation to defer.
    # @param    [Proc]  callback
    #   Block to call with the results of the operation.
    #
    # @param    [Block]  block
    #   Operation to defer.
    def defer( operation = nil, callback = nil, &block )
        Thread.new( *[operation, callback].compact, &block )
    end

    # Runs a block as soon as possible in the Reactor loop.
    #
    # @param    [Block] block
    def run_asap( &block )
        Arachni::Reactor.global.next_tick( &block )
    end

    # @param    [Array]    list
    #
    # @return   [Arachni::Reactor::Iterator]
    #   Iterator for the provided array.
    def iterator_for( list, max_concurrency = 10 )
        Arachni::Reactor.global.create_iterator( list, max_concurrency )
    end

    # @return   [Array<Hash>]
    #   Alive instances.
    def instances
        agent.running_instances
    end

    # Connects to a Agent by `url`
    #
    # @param    [String]    url
    #
    # @return   [Client::Agent]
    def connect_to_agent( url )
        @agent_connections ||= {}
        @agent_connections[url] ||= Client::Agent.new( url )
    end

    # Connects to an Instance by `url`.
    #
    # @example
    #   connect_to_instance( url, token )
    #   connect_to_instance( url: url, token: token )
    #   connect_to_instance( 'url' => url, 'token' => token )
    #
    # @param    [Vararg]    args
    #
    # @return   [Client::Instance]
    def connect_to_instance( *args )
        url = token = nil

        if args.size == 2
            url, token = *args
        elsif args.first.is_a? Hash
            connection_options = args.first
            url     = connection_options['url']   || connection_options[:url]
            token   = connection_options['token'] || connection_options[:token]
        end

        @instance_connections ||= {}
        @instance_connections[url] ||= Client::Instance.new( url, token )
    end

end
end
end
