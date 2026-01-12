module Cuboid
module Processes

#
# Helper for managing {RPC::Server::Instance} processes.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
#
class Instances
    include Singleton
    include Utilities

    # @return   [Array<String>] URLs and tokens of all running Instances.
    attr_reader :list

    def initialize
        @list = {}
        @instance_connections = {}
    end

    #
    # Connects to a Instance by URL.
    #
    # @param    [String]    url URL of the Agent.
    # @param    [String]    token
    #   Authentication token -- only need be provided once.
    #
    # @return   [RPC::Client::Instance]
    #
    def connect( url, token = nil )
        Raktr.global.run_in_thread if !Raktr.global.running?

        token ||= @list[url]
        @list[url] ||= token

        @instance_connections[url] ||= RPC::Client::Instance.new( url, token )
    end

    # @param    [Block] block   Block to pass an RPC client for each Instance.
    def each( &block )
        @list.keys.each do |url|
            block.call connect( url )
        end
    end

    #
    # @param    [String, RPC::Client::Instance] client_or_url
    #
    # @return   [String]    Cached authentication token for the given Instance.
    #
    def token_for( client_or_url )
        @list[client_or_url.is_a?( String ) ? client_or_url : client_or_url.url ]
    end

    # Spawns an {RPC::Server::Instance} process.
    #
    # @param    [Hash]  options
    #   To be passed to {Cuboid::Options#set}. Allows `address` instead of
    #   `rpc_server_address` and `port` instead of `rpc_port`.
    #
    # @return   [RPC::Client::Instance, Integer]
    #   RPC client and PID.
    def spawn( options = {}, &block )
        options = options.dup
        token = options.delete(:token) || Utilities.generate_token
        fork  = options.delete(:fork)

        daemonize  = options.delete(:daemonize)
        port_range = options.delete( :port_range )

        options[:ssl] ||= {
          server: {},
          client: {}
        }

        options = {
            rpc:    {
                server_socket:  options[:socket],
                server_port:    options[:port]    || Utilities.available_port( port_range ),
                server_address: options[:address] || '127.0.0.1',

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

        url = nil
        if options[:rpc][:server_socket]
            url = options[:rpc][:server_socket]

            options[:rpc].delete :server_address
            options[:rpc].delete :server_port
        else
            url = "#{options[:rpc][:server_address]}:#{options[:rpc][:server_port]}"
        end

        pid = Manager.spawn( :instance, options: options, token: token, fork: fork, daemonize: daemonize )

        System.slots.use pid

        client = connect( url, token )
        client.pid = pid

        if block_given?
            client.when_ready do
                block.call client
            end
        else
            while sleep( 0.1 )
                begin
                    client.alive?
                    break
                rescue => e
                    # ap "#{e.class}: #{e}"
                    # ap e.backtrace
                end
            end

            client
        end
    end

    # Starts {RPC::Server::Agent} grid and returns a high-performance Instance.
    #
    # @param    [Hash]  options
    # @option options [Integer] :grid_size (3)  Amount of Agents to spawn.
    #
    # @return   [RPC::Client::Instance]
    def grid_spawn(options = {} )
        options[:grid_size] ||= 3

        last_member = nil
        options[:grid_size].times do |i|
            last_member = Agents.spawn(
                peer: last_member ? last_member.url : last_member,
                pipe_id:   Utilities.available_port.to_s + Utilities.available_port.to_s
            )
        end

        info = nil
        info = last_member.spawn while !info && sleep( 0.1 )

        connect( info['url'], info['token'] )
    end

    # Starts {RPC::Server::Agent} and returns an Instance.
    #
    # @return   [RPC::Client::Instance]
    def agent_spawn
        info = Agents.spawn.spawn
        connect( info['url'], info['token'] )
    end

    def kill( url )
        service = connect( url )

        pids = service.consumed_pids

        service.shutdown rescue nil
        Manager.kill_many pids

        @list.delete url
    end

    # Kills all {Instances #list}.
    def killall
        pids = []
        each do |instance|
            begin
                Timeout.timeout 5 do
                    pids |= instance.consumed_pids
                end
            rescue => e
                #ap e
                #ap e.backtrace
            end
        end

        each do |instance|
            begin
                Timeout.timeout 5 do
                    instance.shutdown
                end
            rescue => e
                #ap e
                #ap e.backtrace
            end
        end

        @list.clear
        @instance_connections.clear
        Manager.kill_many pids
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
