module Cuboid
module Processes

#
# Helper for managing {RPC::Server::Dispatcher} processes.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
#
class Dispatchers
    include Singleton
    include Utilities

    # @return   [Array<String>] URLs of all running Dispatchers.
    attr_reader :list

    def initialize
        @list = []
        @dispatcher_connections = {}
    end

    # Connects to a Dispatcher by URL.
    #
    # @param    [String]    url URL of the Dispatcher.
    # @param    [Hash]    options Options for the RPC client.
    #
    # @return   [RPC::Client::Dispatcher]
    def connect( url, options = nil )
        Arachni::Reactor.global.run_in_thread if !Arachni::Reactor.global.running?

        fresh = false
        if options
            fresh = options.delete( :fresh )
        end

        if fresh
            @dispatcher_connections[url] = RPC::Client::Dispatcher.new( url, options )
        else
            @dispatcher_connections[url] ||= RPC::Client::Dispatcher.new( url, options )
        end
    end

    # @param    [Block] block   Block to pass an RPC client for each Dispatcher.
    def each( &block )
        @list.each do |url|
            block.call connect( url )
        end
    end

    # Spawns a {RPC::Server::Dispatcher} process.
    #
    # @param    [Hash]  options
    #   To be passed to {Cuboid::Options#set}. Allows `address` instead of
    #   `rpc_server_address` and `port` instead of `rpc_port`.
    #
    # @return   [RPC::Client::Dispatcher]
    def spawn( options = {} )
        options = options.dup
        fork = options.delete(:fork)

        options[:ssl] ||= {
          server: {},
          client: {}
        }

        options = {
            dispatcher: {
                name:      options[:name],
                neighbour: options[:neighbour],
                strategy:  options[:strategy],
            },
            rpc:        {
                server_port:             options[:port]    || Utilities.available_port,
                server_address:          options[:address] || '127.0.0.1',
                server_external_address: options[:external_address],

                ssl_ca:                 options[:ssl][:ca],
                server_ssl_private_key: options[:ssl][:server][:private_key],
                server_ssl_certificate: options[:ssl][:server][:certificate],
                client_ssl_private_key: options[:ssl][:client][:private_key],
                client_ssl_certificate: options[:ssl][:client][:certificate],
            },
            paths: {
                application: options[:application] || Options.paths.application
            }
        }

        if options[:rpc][:server_external_address].nil?
            options[:rpc].delete :server_external_address
        end

        if options[:dispatcher][:neighbour].nil?
            options[:dispatcher].delete :neighbour
        end

        pid = Manager.spawn( :dispatcher, options: options, fork: fork )

        url = "#{options[:rpc][:server_address]}:#{options[:rpc][:server_port]}"
        while sleep( 0.1 )
            begin
                connect( url, connection_pool_size: 1, max_retries: 1 ).alive?
                break
            rescue => e
                # ap e
            end
        end

        @list << url
        connect( url, fresh: true ).tap { |c| c.pid = pid }
    end

    def grid_spawn( options = {} )
        d = spawn( options )
        spawn( options.merge neighbour: d.url )
    end

    # @note Will also kill all Instances started by the Dispatcher.
    #
    # @param    [String]    url URL of the Dispatcher to kill.
    def kill( url )
        dispatcher = connect( url )
        Manager.kill_many dispatcher.statistics['consumed_pids']
        Manager.kill dispatcher.pid
    rescue => e
        #ap e
        #ap e.backtrace
        nil
    ensure
        @list.delete( url )
        @dispatcher_connections.delete( url )
    end

    # Kills all {Dispatchers #list}.
    def killall
        @list.dup.each do |url|
            kill url
        end
    end

    def self.method_missing( sym, *args, &block )
        if instance.respond_to?( sym )
            instance.send( sym, *args, &block )
        else
            super( sym, *args, &block )
        end
    end

    def self.respond_to?( m )
        super( m ) || instance.respond_to?( m )
    end

end

end
end
