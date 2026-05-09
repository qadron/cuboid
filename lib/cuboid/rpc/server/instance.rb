require 'ostruct'

module Cuboid
lib = Options.paths.lib

require lib + 'processes/manager'

require lib + 'rpc/client/instance'

require lib + 'rpc/server/base'
require lib + 'rpc/server/active_options'
require lib + 'rpc/server/output'
require lib + 'rpc/server/application_wrapper'

require lib + 'rpc/server/instance/service'
require lib + 'rpc/server/instance/peers'

module RPC
class Server

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Instance
    include UI::Output
    include Utilities

    [
        :suspend!, :suspended?, :snapshot_path,
        :pause!,   :paused?,
        :abort!,   :resume!,
        :running?, :status
    ].each do |m|
        define_method m do
            @application.send m
        end
    end

    private :error_logfile
    public  :error_logfile

    # Initializes the RPC interface and the framework.
    #
    # @param    [Options]    options
    # @param    [String]    token
    #   Authentication token.
    def initialize( options, token )
        @options = options
        @token   = token

        @application    = Server::ApplicationWrapper.new(
          Cuboid::Application.application
        )
        @active_options = Server::ActiveOptions.new

        @server = Base.new( @options.rpc.to_server_options, token )

        if @options.datastore.log_level
            @server.logger.level = @options.datastore.log_level
        end

        @options.datastore.token = token

        if @options.output.reroute_to_logfile
            reroute_to_file "#{@options.paths.logs}Instance-#{Process.pid}-#{@options.rpc.server_port}.log"
        else
            reroute_to_file false
        end

        set_error_logfile "#{@options.paths.logs}Instance-#{Process.pid}-#{@options.rpc.server_port}.error.log"

        set_handlers( @server )

        # trap interrupts and exit cleanly when required
        %w(QUIT INT).each do |signal|
            next if !Signal.list.has_key?( signal )
            trap( signal ){ shutdown if !@options.datastore.do_not_trap }
        end

        @raktr = Raktr.new
        @raktr.run do
            _run
        end
    end

    def application
        Application.application.to_s
    end

    # @return   [String, nil]
    #   Scheduler URL to which this Instance is attached, `nil` if not attached.
    def scheduler_url
        @options.scheduler.url
    end

    # @return   [String, nil]
    #   Agent URL that provided this Instance, `nil` if not provided by a
    #   Agent.
    def agent_url
        @options.agent.url
    end

    # @param (see Cuboid::Application#restore)
    # @return (see Cuboid::Application#restore)
    #
    # @see #suspend
    # @see #snapshot_path
    def restore!( snapshot )
        # If the instance isn't clean bail out now.
        return false if busy? || @called

        @called = @run_initializing = true

        Thread.new do
            @application.restore!( snapshot )
            @application.run
            @run_initializing = false
        end

        true
    end

    # @return   [true]
    def alive?
        @server.alive?
    end

    # @return   [Bool]
    #   `true` if the scan is initializing or running, `false` otherwise.
    def busy?
        @run_initializing || @application.busy?
    end

    # Cleans up and returns the report.
    #
    # @return  [Hash]
    #
    # @see #report
    def abort_and_generate_report
        @application.abort!
        generate_report
    end

    # @return [Hash]
    #   {Report#to_rpc_data}
    def generate_report
        @application.generate_report.to_rpc_data
    end

    # # Recommended usage
    #
    #   Please request from the method only the things you are going to actually
    #   use, otherwise you'll just be wasting bandwidth.
    #   In addition, ask to **not** be served data you already have, like
    #   error messages.
    #
    #   Pass a `session:` token (any caller-chosen string) and the
    #   server returns only error lines past the previous offset
    #   under that token. Reuse the same token across polls for
    #   the same logical view; pick a fresh one to start fresh.
    #
    #     token = SecureRandom.uuid
    #     while sleep 1
    #         errors = instance.progress( session: token )[:errors]
    #         puts errors.join( "\n" )
    #     end
    #
    #   Without `session`, callers must opt into errors via
    #   `with: [:errors]` and will receive the full set every poll.
    #
    # @param  [Hash]  options
    # @option options [String, Symbol] :session
    #   Caller-chosen session token. When provided, the response
    #   carries only errors past the previously emitted offset.
    # @option options [Array<Symbol>]  :with
    #   Block names to include when no session is in use. Currently
    #   only `:errors` is delta-able.
    # @option options [Array<Symbol>]  :without
    #   Block names to exclude. One or more of `:statistics`,
    #   `:errors`. Takes precedence over `with:` and over the
    #   session-on-by-default blocks.
    #
    # @return [Hash]
    #   * `statistics` -- General runtime statistics (merged when part of Grid)
    #       (enabled by default)
    #   * `status` -- {#status}
    #   * `busy` -- {#busy?}
    #   * `errors` -- {#errors}
    def progress( options = {} )
        progress_handler( options.merge( as_hash: true ) )
    end

    # Configures and runs a job.
    def run( options = nil )
        # If the instance isn't clean bail out now.
        return false if busy? || @called

        if !@application.valid_options?( options )
            fail ArgumentError, 'Invalid options!'
        end

        # There may be follow-up/retry calls by the client in cases of network
        # errors (after the request has reached us) so we need to keep minimal
        # track of state in order to bail out on subsequent calls.
        @called = @run_initializing = true

        @active_options.set( application: options )

        Thread.new do
            @application.run
            @run_initializing = false
        end

        true
    end

    # Makes the server go bye-bye...Lights out!
    #
    # `shutdown` must reliably take the Ruby process with it. Stopping
    # the reactor + RPC server alone leaves the Application's non-daemon
    # threads (audit workers, browser cluster manager, etc.) blocking
    # the runtime — historically this leaked engine subprocesses every
    # time `kill_instance` was called over MCP, and showed up in the
    # cuboid spec suite as leftover ruby processes after the run.
    # The `instance.shutdown` RPC returned success but the daemonised
    # process never actually exited.
    #
    # Two-stage exit:
    #   1. Raise SystemExit on the **main thread** so the at_exit
    #      chain runs (Cuboid_<pid> tmpdir cleanup, live-plugin's
    #      `exited` push). SystemExit raised on a non-main thread
    #      only kills that thread — must hit the main one.
    #   2. Watchdog SIGKILL after a grace window in case a
    #      non-daemon Application thread refuses to release. The
    #      Paths boot-sweep reaps the orphaned tmpdir on the next
    #      cuboid process launch even when at_exit didn't run.
    SHUTDOWN_GRACE_SECONDS = 5.0

    def shutdown( &block )
        if @shutdown
            block.call if block_given?
            return
        end
        @shutdown = true

        print_status 'Shutting down...'

        @application.shutdown

        # We're shutting down services so we need to use a concurrent way but
        # without going through the Reactor.
        Thread.new do
            @server.shutdown
            @raktr.stop
            block.call true if block_given?

            # Stage 1 — graceful: SystemExit on the main thread so
            # at_exit handlers run.
            main = Thread.main
            if main && main.alive? && main != Thread.current
                main.raise( SystemExit.new( 0 ) ) rescue nil
            end

            # Stage 2 — watchdog: hammer if main can't unwind.
            sleep SHUTDOWN_GRACE_SECONDS
            Process.kill( 'KILL', Process.pid ) rescue nil
        end

        true
    end

    def errors( starting_line = 0 )
        @application.errors( starting_line )
    end

    # @private
    def error_test( str )
        @application.error_test( str )
    end

    # @private
    def consumed_pids
        [Process.pid]
    end

    def self.parse_block_names( raw )
        return [] if raw.nil?
        Array( raw ).flatten.compact.map(&:to_sym)
    end

    private

    # Server-side state for `session:`-tracked progress polls.
    # Keyed off a caller-supplied token so RPC clients don't have
    # to re-transmit the error line offset on every poll.
    def progress_sessions
        @progress_sessions ||= {}
    end

    def progress_session_for( id )
        progress_sessions[id] ||= { seen_errors: 0 }
    end

    def progress_handler( options = {}, &block )
        options = options.my_symbolize_keys

        session_id = options.delete( :session )
        session    = progress_session_for( session_id ) if session_id

        with    = self.class.parse_block_names( options[:with] )
        without = self.class.parse_block_names( options[:without] )

        # Under a session, errors are on by default; without a
        # session, callers opt in via `with: [:errors]`.
        include_errors = !without.include?( :errors ) && (session || with.include?( :errors ))

        wrapper_options = {
            as_hash:    options[:as_hash],
            statistics: !without.include?( :statistics )
        }
        wrapper_options[:errors] = session ? session[:seen_errors] : 0 if include_errors

        @application.progress( wrapper_options ) do |data|
            data[:busy] = busy?

            if session && data[:errors]
                session[:seen_errors] += data[:errors].size
            end

            block.call( data )
        end
    end

    # Starts  RPC services.
    def _run
        @raktr.on_error do |_, e|
            print_error "Reactor: #{e}"

            e.backtrace.each do |l|
                print_error "Reactor: #{l}"
            end
        end

        print_status 'Starting the Instance...'
        @server.start
    end

    # Outputs the Engine banner.
    #
    # Displays version number, author details etc.
    def banner
        puts BANNER
        puts
        puts
    end

    # @param    [Base]  server
    #   Prepares all the RPC handlers for the given `server`.
    def set_handlers( server )
        server.add_async_check do |method|
            # methods that expect a block are async
            method.parameters.flatten.include? :block
        end

        server.add_handler( 'instance', self )
        server.add_handler( 'options',  @active_options )

        Cuboid::Application.application.instance_services.each do |name, service|
            service.include Server::Instance::Service
            si = service.new( name, self )

            Cuboid::Application.application.send :attr_reader, name
            @application.application.instance_variable_set( "@#{name}".to_sym, si )

            server.add_handler( name.to_s, si )
        end
    end

end

end
end
end
