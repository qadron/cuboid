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
# * A client issues a {#dispatch} call.
# * The Dispatcher spawns and returns Instance info to the client (url, auth token, etc.).
# * The client connects to the Instance using that info.
#
# Once the client finishes using the RPC Instance it *must* shut it down
# otherwise the system will be eaten away by zombie processes.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Dispatcher
    require Options.paths.lib + 'rpc/server/dispatcher/node'
    require Options.paths.lib + 'rpc/server/dispatcher/service'

    include Utilities
    include UI::Output

    SERVICE_NAMESPACE = Service

    def initialize( options = Options.instance )
        @options = options

        @options.snapshot.path ||= @options.paths.snapshots

        @server = Base.new( @options.rpc.to_server_options )
        @server.logger.level = @options.datastore.log_level if @options.datastore.log_level

        @server.add_async_check do |method|
            # methods that expect a block are async
            method.parameters.flatten.include? :block
        end

        Options.dispatcher.url = @url = @server.url

        prep_logging

        print_status 'Starting the RPC Server...'

        @server.add_handler( 'dispatcher', self )

        # trap interrupts and exit cleanly when required
        trap_interrupts { shutdown }

        @instances = []

        Cuboid::Application.application.dispatcher_services.each do |name, service|
            @server.add_handler( name.to_s, service.new( @options, self ) )
        end

        @node = Node.new( @options, @server, @logfile )
        @server.add_handler( 'node', @node )

        run
    end

    def services
        Cuboid::Application.application.dispatcher_services.keys
    end

    # @return   [TrueClass]
    #   true
    def alive?
        @server.alive?
    end

    # @return   [String, nil]
    #   Depending on availability:
    #
    #   * URL of the least burdened Dispatcher. If not a grid member it will
    #       return this Dispatcher's URL.
    #   * `nil` if all nodes are at max utilization.
    def preferred( &block )
        if !@node.grid_member?
            block.call( self.utilization == 1 ? nil : @url )
            return
        end

        pick_utilization = proc do |url, utilization|
            (utilization == 1 || utilization.rpc_exception?) ?
                nil : [url, utilization]
        end

        each = proc do |neighbour, iter|
            connect_to_peer( neighbour ).utilization do |utilization|
                iter.return pick_utilization.call( neighbour, utilization )
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

            block.call nodes.sort_by { |_, score| score }[0][0]
        end

        Arachni::Reactor.global.create_iterator( @node.neighbours ).map( each, after )
    end

    # Dispatches an {Instance}.
    #
    # @param    [String]  owner
    #   An owner to assign to the {Instance}.
    # @param    [Hash]    helpers
    #   Hash of helper data to be added to the instance info.
    # @param    [Boolean]    load_balance
    #   Return an {Instance} from the least burdened {Dispatcher} (when in Grid mode)
    #   or from this one directly?
    #
    # @return   [Hash, nil]
    #   Depending on availability:
    #
    #   * `Hash`: Connection and proc info.
    #   * `nil`: Max utilization, wait for one of the instances to finish and retry.
    def dispatch( options = {}, &block )
        options      = options.my_symbolize_keys
        owner        = options[:owner]
        helpers      = options[:helpers] || {}
        load_balance = options[:load_balance].nil? ? true : options[:load_balance]

        if load_balance && @node.grid_member?
            preferred do |url|
                if !url
                    block.call
                    next
                end

                connect_to_peer( url ).dispatch( options.merge(
                      helpers: helpers.merge( via: @url ),
                      load_balance: false
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

        spawn_instance do |info|
            info['owner']   = owner
            info['helpers'] = helpers

            @instances << info

            block.call info
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
    #   Workload score for this Dispatcher, calculated using {System#utilization}.
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

    # Starts the dispatcher's server
    def run
        Arachni::Reactor.global.on_error do |_, e|
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
            Arachni::Reactor.global.stop
        end
    end

    def spawn_instance( options = {}, &block )
        Processes::Instances.spawn( options.merge(
            address:     @server.address,
            port_range:  Options.dispatcher.instance_port_range,
            token:       Utilities.generate_token,
            application: Options.paths.application
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
            "/Dispatcher - #{Process.pid}-#{@options.rpc.server_port}.log" )
    end

    def connect_to_peer( url )
        @rpc_clients ||= {}
        @rpc_clients[url] ||= Client::Dispatcher.new( url )
    end

end

end
end
end