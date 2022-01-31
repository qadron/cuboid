module Cuboid
module Processes

#
# Helper for managing {RPC::Server::Agent} processes.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
#
class Agents
    include Singleton
    include Utilities

    # @return   [Array<String>] URLs of all running Agents.
    attr_reader :list

    def initialize
        @list = []
        @agent_connections = {}
    end

    # Connects to a Agent by URL.
    #
    # @param    [String]    url URL of the Agent.
    # @param    [Hash]    options Options for the RPC client.
    #
    # @return   [RPC::Client::Agent]
    def connect( url, options = nil )
        Arachni::Reactor.global.run_in_thread if !Arachni::Reactor.global.running?

        fresh = false
        if options
            fresh = options.delete( :fresh )
        end

        if fresh
            @agent_connections[url] = RPC::Client::Agent.new( url, options )
        else
            @agent_connections[url] ||= RPC::Client::Agent.new( url, options )
        end
    end

    # @param    [Block] block   Block to pass an RPC client for each Agent.
    def each( &block )
        @list.each do |url|
            block.call connect( url )
        end
    end

    # Spawns a {RPC::Server::Agent} process.
    #
    # @param    [Hash]  options
    #   To be passed to {Cuboid::Options#set}. Allows `address` instead of
    #   `rpc_server_address` and `port` instead of `rpc_port`.
    #
    # @return   [RPC::Client::Agent]
    def spawn( options = {} )
        options = options.dup
        fork = options.delete(:fork)

        options[:ssl] ||= {
          server: {},
          client: {}
        }

        options = {
            agent: {
                name:      options[:name],
                peer: options[:peer],
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

        if options[:agent][:peer].nil?
            options[:agent].delete :peer
        end

        pid = Manager.spawn( :agent, options: options, fork: fork )

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
        spawn( options.merge peer: d.url )
    end

    # @note Will also kill all Instances started by the Agent.
    #
    # @param    [String]    url URL of the Agent to kill.
    def kill( url )
        agent = connect( url )
        Manager.kill_many agent.statistics['consumed_pids']
        Manager.kill agent.pid
    rescue => e
        #ap e
        #ap e.backtrace
        nil
    ensure
        @list.delete( url )
        @agent_connections.delete( url )
    end

    # Kills all {Agents #list}.
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
