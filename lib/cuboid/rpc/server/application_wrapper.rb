require 'tempfile'
require 'forwardable'

module Cuboid

lib = Options.paths.lib
require lib + 'application'

module RPC
class Server

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class ApplicationWrapper
    include Utilities

    attr_reader :application

    extend Forwardable
    def_delegators :@application, :suspended?, :suspending?, :suspend!, :status,
                   :pause!, :running?, :status_messages, :paused?, :pausing?,
                   :snapshot_path, :restore!, :resume!, :generate_report,
                   :abort!, :aborting?, :aborted?, :shutdown

    # {RPC::Server::Application} error namespace.
    #
    # All {RPC::Server::Application} errors inherit from and live under it.
    #
    # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
    class Error < Cuboid::Application::Error
    end

    def initialize( application )
        super()

        @application = application.instance
        @extended_running = false
    end

    def valid_options?( options )
        @application.class.valid_options?( options )
    end

    # @return   [Bool]
    #   `true` If the system is scanning, `false` if {#run} hasn't been called
    #   yet or if the scan has finished.
    def busy?
        ![:ready, :done, :suspended].include?( @application.status ) &&
          !!@extended_running
    end

    # @return   [Bool]
    #   `false` if already running, `true` otherwise.
    def run
        # Return if we're already running.
        return false if busy?
        @extended_running = true

        # Start the scan  -- we can't block the RPC server so we're using a Thread.
        Thread.new do
            @application.run
        end

        true
    end

    def clean_up
        return false if @rpc_cleaned_up

        @rpc_cleaned_up   = true
        @extended_running = false

        @application.clean_up
    end

    # @param    [Integer]   starting_line
    #   Sets the starting line for the range of errors to return.
    #
    # @return   [Array<String>]
    def errors( starting_line = 0 )
        return [] if UI::Output.error_buffer.empty?

        error_strings = UI::Output.error_buffer

        if starting_line != 0
            error_strings = error_strings[starting_line..-1]
        end

        error_strings
    end

    # Provides aggregated progress data.
    #
    # @param    [Hash]  opts
    #   Options about what data to include:
    # @option opts [Bool] :statistics   (true)
    #   Master/merged statistics.
    # @option opts [Bool, Integer] :errors   (false)
    #   Logged errors. If an integer is provided it will return errors past that
    #   index.
    #
    # @return    [Hash]
    #   Progress data.
    def progress( opts = {} )
        opts = opts.my_symbolize_keys

        include_statistics = opts[:statistics].nil? ? true : opts[:statistics]
        include_errors     = opts.include?( :errors ) ?
            (opts[:errors] || 0) : false

        data = {
            status:         status,
            busy:           running?,
            application:    @application.class.to_s,
            seed:           Utilities.random_seed,
            agent_url: Cuboid::Options.agent.url,
            scheduler_url:  Cuboid::Options.scheduler.url
        }

        if include_statistics
            data[:statistics] = @application.statistics
        end

        if include_errors
            data[:errors] =
                errors( include_errors.is_a?( Integer ) ? include_errors : 0 )
        end

        data.merge( messages: status_messages )
    end

    # @private
    def error_test( str )
        @application.print_error str.to_s
    end

end

end
end
end
