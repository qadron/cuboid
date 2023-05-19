module Cuboid

lib = Options.paths.lib
require lib + 'processes/instances'
require lib + 'rpc/client'
require lib + 'rpc/server/base'
require lib + 'rpc/server/instance'
require lib + 'rpc/server/output'

module RPC
class Server

# Dispatches RPC Instances on demand and allows for extensive process monitoring.
#
# The process goes something like this:
#
# * A client issues a {#spawn} call.
# * The Agent spawns and returns Instance info to the client (url, auth token, etc.).
# * The client connects to the Instance using that info.
#
# Once the client finishes using the RPC Instance it *must* shut it down
# otherwise the system will be eaten away by zombie processes.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Agent
    require Options.paths.lib + 'rpc/server/agent/node'
    require Options.paths.lib + 'rpc/server/agent/service'

    include Utilities
    include UI::Output

    SERVICE_NAMESPACE = Service

    PREFERENCE_STRATEGIES = Cuboid::OptionGroups::Agent::STRATEGIES

    def initialize( options = Options.instance )
        @options = options

        @options.snapshot.path ||= @options.paths.snapshots

        @server = Base.new( @options.rpc.to_server_options )
        @server.logger.level = @options.datastore.log_level if @options.datastore.log_level

        @server.add_async_check do |method|
            # methods that expect a block are async
            method.parameters.flatten.include? :block
        end

        Options.agent.url = @url = @server.url

        prep_logging

        print_status 'Starting the Agent...'
        @server.logger.info( 'System' ) { "Logfile at: #{@logfile}"  }

        @server.add_handler( 'agent', self )

        # trap interrupts and exit cleanly when required
        trap_interrupts { shutdown }

        @instances = []

        Cuboid::Application.application.agent_services.each do |name, service|
            @server.add_handler( name.to_s, service.new( @options, self ) )
        end

        @node = Node.new( @options, @server, @logfile )
        @server.add_handler( 'node', @node )

        run
    end

    def services
        Cuboid::Application.application.agent_services.keys
    end

    # @return   [TrueClass]
    #   true
    def alive?
        @server.alive?
    end

    # @param    [Symbol]    strategy
    #   `:horizontal` -- Pick the Agent with the least amount of workload.
    #   `:vertical` -- Pick the Agent with the most amount of workload.
    #   `:direct` -- Bypass the grid and get an Instance directly from this agent.
    #
    # @return   [String, nil]
    #   Depending on strategy and availability:
    #
    #   * URL of the preferred Agent. If not a grid member it will return
    #       this Agent's URL.
    #   * `nil` if all nodes are at max utilization or on error.
    #   * `ArgumentError` -- On invalid `strategy`.
    def preferred( strategy = Cuboid::Options.agent.strategy, &block )
        strategy = strategy.to_sym
        if !PREFERENCE_STRATEGIES.include? strategy
            block.call :error_unknown_strategy
            raise ArgumentError, "Unknown strategy: #{strategy}"
        end

        if strategy == :direct || !@node.grid_member?
            block.call( self.utilization == 1 ? nil : @url )
            return
        end

        pick_utilization = proc do |url, utilization|
            (utilization == 1 || utilization.rpc_exception?) ?
                nil : [url, utilization]
        end

        adjust_score_by_strategy = proc do |score|
            case strategy
                when :horizontal
                    score

                when :vertical
                    -score
            end
        end

        each = proc do |peer, iter|
            connect_to_peer( peer ).utilization do |utilization|
                iter.return pick_utilization.call( peer, utilization )
            end
        end

        after = proc do |nodes|
            nodes << pick_utilization.call( @url, self.utilization )
            nodes.compact!

            # All nodes are at max utilization, pass.
            if nodes.empty?
                block.call
                next
            end

            block.call nodes.sort_by { |_, score| adjust_score_by_strategy.call score }[0][0]
        end

        Raktr.global.create_iterator( @node.peers ).map( each, after )
    end

    # Spawns an {Instance}.
    #
    # @param    [String]  options
    # @option    [String]  strategy
    # @option    [String]  owner
    #   An owner to assign to the {Instance}.
    # @option    [Hash]    helpers
    #   Hash of helper data to be added to the instance info.
    #
    # @return   [Hash, nil]
    #   Depending on availability:
    #
    #   * `Hash`: Connection and proc info.
    #   * `nil`: Max utilization or currently spawning, wait and retry.
    def spawn( options = {}, &block )
        if @spawning
            block.call nil
            return
        end

        options      = options.my_symbolize_keys
        strategy     = options.delete(:strategy)
        owner        = options[:owner]
        helpers      = options[:helpers] || {}

        if strategy != 'direct' && @node.grid_member?
            preferred *[strategy].compact do |url|
                if !url
                    block.call
                    next
                end

                if url == :error_unknown_strategy
                    block.call :error_unknown_strategy
                    next
                end

                connect_to_peer( url ).spawn( options.merge(
                      helpers:  helpers.merge( via: @url ),
                      strategy: :direct
                    ),
                    &block
                )
            end
            return
        end

        if System.max_utilization?
            block.call
            return
        end

        @spawning = true
        spawn_instance do |info|
            info['owner']   = owner
            info['helpers'] = helpers

            @instances << info

            block.call info

            @spawning = false
        end
    end

    # Returns proc info for a given pid
    #
    # @param    [Fixnum]      pid
    #
    # @return   [Hash]
    def instance( pid )
        @instances.each do |i|
            next if i['pid'] != pid
            i = i.dup

            now = Time.now

            i['now']   = now.to_s
            i['age']   = now - Time.parse( i['birthdate'] )
            i['alive'] = Cuboid::Processes::Manager.alive?( pid )

            return i
        end

        nil
    end

    # @return   [Array<Hash>]
    #   Returns info for all instances.
    def instances
        @instances.map { |i| instance( i['pid'] ) }.compact
    end

    # @return   [Array<Hash>]
    #   Returns info for all running (alive) instances.
    #
    # @see #instances
    def running_instances
        instances.select { |i| i['alive'] }
    end

    # @return   [Array<Hash>]
    #   Returns info for all finished (dead) instances.
    #
    # @see #instances
    def finished_instances
        instances.reject { |i| i['alive'] }
    end

    # @return   [Float]
    #   Workload score for this Agent, calculated using {System#utilization}.
    #
    #   * `0.0` => No utilization.
    #   * `1.0` => Max utilization.
    #
    #   Lower is better.
    def utilization
        System.utilization
    end

    # @return   [Hash]
    #   Returns server stats regarding the instances and pool.
    def statistics
        {
            'utilization'         => utilization,
            'running_instances'   => running_instances,
            'finished_instances'  => finished_instances,
            'consumed_pids'       => @instances.map { |i| i['pid'] }.compact,
            'snapshots'           => Dir.glob( "#{@options.snapshot.path}*.#{Snapshot::EXTENSION}" ),
            'node'                => @node.info
        }
    end

    # @return   [String]
    #   Contents of the log file
    def log
        IO.read prep_logging
    end

    # @private
    def pid
        Process.pid
    end

    private

    def trap_interrupts( &block )
        %w(QUIT INT).each do |signal|
            trap( signal, &block || Proc.new{ } ) if Signal.list.has_key?( signal )
        end
    end

    # Starts the agent's server
    def run
        Raktr.global.on_error do |_, e|
            print_error "Reactor: #{e}"

            e.backtrace.each do |l|
                print_error "Reactor: #{l}"
            end
        end

        print_status 'Ready'
        @server.start
    rescue => e
        print_exception e

        $stderr.puts "Could not start server, for details see: #{@logfile}"
        exit 1
    end

    def shutdown
        Thread.new do
            print_status 'Shutting down...'
            Raktr.global.stop
        end
    end

    def spawn_instance( options = {}, &block )
        Processes::Instances.spawn( options.merge(
            address:     @server.address,
            port_range:  Options.agent.instance_port_range,
            token:       Utilities.generate_token,
            application: Options.paths.application,
            daemonize:   true
        )) do |client|
            block.call(
                'token'       => client.token,
                'url'         => client.url,
                'pid'         => client.pid,
                'birthdate'   => Time.now.to_s,
                'application' => Options.paths.application
            )
        end
    end

    def prep_logging
        # reroute all output to a logfile
        @logfile ||= reroute_to_file( @options.paths.logs +
            "Agent-#{Process.pid}-#{@options.rpc.server_port}.log" )
    end

    def connect_to_peer( url )
        @rpc_clients ||= {}
        @rpc_clients[url] ||= Client::Agent.new( url )
    end

end

end
end
end
