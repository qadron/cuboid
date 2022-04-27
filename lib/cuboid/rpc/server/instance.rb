require 'ostruct'

module Cuboid
lib = Options.paths.lib

require lib + 'processes/manager'

require lib + 'rpc/client/instance'

require lib + 'rpc/server/base'
require lib + 'rpc/server/active_options'
require lib + 'rpc/server/output'
require lib + 'rpc/server/application_wrapper'

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
            reroute_to_file "#{@options.paths.logs}/Instance - #{Process.pid}" <<
                                "-#{@options.rpc.server_port}.log"
        else
            reroute_to_file false
        end

        set_error_logfile "#{@options.paths.logs}/Instance - #{Process.pid}" <<
                              "-#{@options.rpc.server_port}.error.log"

        set_handlers( @server )

        # trap interrupts and exit cleanly when required
        %w(QUIT INT).each do |signal|
            next if !Signal.list.has_key?( signal )
            trap( signal ){ shutdown if !@options.datastore.do_not_trap }
        end

        Raktr.global.run do
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
        Thread.new do
            @application.restore!( snapshot ).run
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
    #   To be kept completely up to date on the progress of a scan (i.e. receive
    #   new issues and error messages asap) in an efficient manner, you will need
    #   to keep track of the error messages you already have and explicitly tell
    #   the method to not send the same data back to you on subsequent calls.
    #
    # ## Retrieving errors (`:errors` option) without duplicate data
    #
    #   This is done by telling the method how many error messages you already
    #   have and you will be served the errors from the error-log that are past
    #   that line.
    #   So, if you were to use a loop to get fresh progress data it would look
    #   like so:
    #
    #     error_cnt = 0
    #     i = 0
    #     while sleep 1
    #         # Test method, triggers an error log...
    #         instance.error_test "BOOM! #{i+=1}"
    #
    #         # Only request errors we don't already have
    #         errors = instance.progress( with: { errors: error_cnt } )[:errors]
    #         error_cnt += errors.size
    #
    #         # You will only see new errors
    #         puts errors.join("\n")
    #     end
    #
    # @param  [Hash]  options
    #   Options about what progress data to retrieve and return.
    # @option options [Array<Symbol, Hash>]  :with
    #   Specify data to include:
    #
    #   * :errors -- Errors and the line offset to use for {#errors}.
    #     Pass as a hash, like: `{ errors: 10 }`
    # @option options [Array<Symbol, Hash>]  :without
    #   Specify data to exclude:
    #
    #   * :statistics -- Don't include runtime statistics.
    #
    # @return [Hash]
    #   * `statistics` -- General runtime statistics (merged when part of Grid)
    #       (enabled by default)
    #   * `status` -- {#status}
    #   * `busy` -- {#busy?}
    #   * `errors` -- {#errors} (disabled by default)
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
            block.call true if block_given?
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

    def self.parse_progress_opts( options, key )
        parsed = {}
        [options.delete( key ) || options.delete( key.to_s )].compact.each do |w|
            case w
                when Array
                    w.compact.flatten.each do |q|
                        case q
                            when String, Symbol
                                parsed[q.to_sym] = nil

                            when Hash
                                parsed.merge!( q.my_symbolize_keys )
                        end
                    end

                when String, Symbol
                    parsed[w.to_sym] = nil

                when Hash
                    parsed.merge!( w.my_symbolize_keys )
            end
        end

        parsed
    end

    private

    def progress_handler( options = {}, &block )
        with    = self.class.parse_progress_opts( options, :with )
        without = self.class.parse_progress_opts( options, :without )

        options = {
            as_hash:    options[:as_hash],
            statistics: !without.include?( :statistics )
        }

        if with[:errors]
            options[:errors] = with[:errors]
        end

        @application.progress( options ) do |data|
            data[:busy] = busy?
            block.call( data )
        end
    end

    # Starts  RPC service.
    def _run
        Raktr.global.on_error do |_, e|
            print_error "Reactor: #{e}"

            e.backtrace.each do |l|
                print_error "Reactor: #{l}"
            end
        end

        print_status 'Starting the server...'
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
            server.add_handler( name.to_s, service.new )
        end
    end

end

end
end
end
