module Cuboid
module Processes

# Helper for managing {RPC::Server::Scheduler} processes.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Schedulers
    include Singleton
    include Utilities

    # @return   [Array<String>] URLs of all running Queues.
    attr_reader :list

    def initialize
        @list    = []
        @clients = {}
    end

    # Connects to a Scheduler by URL.
    #
    # @param    [String]    url URL of the Scheduler.
    # @param    [Hash]    options Options for the RPC client.
    #
    # @return   [RPC::Client::Scheduler]
    def connect( url, options = nil )
        Arachni::Reactor.global.run_in_thread if !Arachni::Reactor.global.running?

        fresh = false
        if options
            fresh = options.delete( :fresh )
        end

        if fresh
            @clients[url] = RPC::Client::Scheduler.new( url, options )
        else
            @clients[url] ||= RPC::Client::Scheduler.new( url, options )
        end
    end

    # @param    [Block] block   Block to pass an RPC client for each Scheduler.
    def each( &block )
        @list.each do |url|
            block.call connect( url )
        end
    end

    # Spawns a {RPC::Server::Scheduler} process.
    #
    # @param    [Hash]  options
    #   To be passed to {Cuboid::Options#set}. Allows `address` instead of
    #   `rpc_server_address` and `port` instead of `rpc_port`.
    #
    # @return   [RPC::Client::Queue]
    def spawn( options = {} )
        options = options.dup
        fork = options.delete(:fork)

        options[:ssl] ||= {
          server: {},
          client: {}
        }

        options = {
            dispatcher: {
                url:      options[:dispatcher],
                strategy: options[:strategy]
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
              application: options[:application]  || Options.paths.application
            }
        }

        pid = Manager.spawn( :scheduler, options: options, fork: fork )

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

    # @note Will also kill all Instances started by the Scheduler.
    #
    # @param    [String]    url URL of the Scheduler to kill.
    def kill( url )
        scheduler = connect( url )
        scheduler.clear
        scheduler.running.each do |id, instance|
            Manager.kill instance['pid']
        end
        Manager.kill scheduler.pid
    rescue => e
        #ap e
        #ap e.backtrace
        nil
    ensure
        @list.delete( url )
        @clients.delete( url ).close
    end

    # Kills all {Queues #list}.
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
