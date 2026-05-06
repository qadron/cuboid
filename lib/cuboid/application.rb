# encoding: utf-8

require 'rubygems'
require 'json'
require 'monitor'
require 'bundler/setup'

require_relative 'options'

module Cuboid

lib = Options.paths.lib
require lib + 'support/mixins/spec_instances'
require lib + 'system'
require lib + 'version'
require lib + 'support'
require lib + 'ruby'
require lib + 'error'
require lib + 'utilities'
require lib + 'snapshot'
require lib + 'report'
require lib + 'processes'
require lib + 'application/runtime'

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Application
    include Singleton

    module PrependMethods

        def run
            if !self.class.valid_options?( options )
                fail ArgumentError, 'Invalid options!'
            end

            prepare
            return if aborted? || suspended?

            state.status = :running

            super if defined? super

            return if aborted? || suspended?

            clean_up
            state.status = :done

            true
        end

        # Cleans up the framework; should be called after running the application
        # or after canceling a running instance.
        def clean_up
            return if @cleaned_up
            @cleaned_up = true

            state.resume

            state.status = :cleanup

            @finish_datetime  = Time.now
            @start_datetime ||= Time.now

            state.running = false

            super if defined? super

            true
        end

        def shutdown
            super if defined? super
        end

        private

        # @note Must be called before calling any audit methods.
        #
        # Prepares the framework for the audit.
        #
        # * Sets the status to `:preparing`.
        # * Starts the clock.
        def prepare
            state.status  = :preparing
            state.running = true
            @start_datetime = Time.now

            super if defined? super
        end

    end

    class <<self

        def provision_cores( cores )
            @max_cores = cores
        end

        def max_cores
            @max_cores ||= 0
        end

        def provision_memory( ram )
            @max_memory = ram
        end

        def max_memory
            @max_memory ||= 0
        end

        def provision_disk( disk )
            @max_disk = disk
        end

        def max_disk
            @max_disk ||= 0
        end

        def instance_service_for( name, service )
            instance_services[name] = service
        end

        def instance_services
            @instance_services ||= {}
        end

        def rest_service_for( name, service )
            rest_services[name] = service
        end

        def rest_services
            @rest_services ||= {}
        end

        # Register an MCP service handler. Mirrors `rest_service_for`:
        # the application gem provides a module/class that exposes a
        # set of tools and Cuboid::MCP::Server mounts them per-instance
        # at `/instances/:instance/<name>` (just like REST mounts
        # rest_service handlers at `/instances/:instance/<name>`).
        #
        # The handler must respond to `.tools`, returning an Array of
        # `MCP::Tool` subclasses. Each tool's `call` receives a
        # `server_context:` Hash containing at least `:instance` —
        # the resolved RPC client for the engine instance the request
        # is targeting.
        #
        # Example:
        #
        #     module MyApp::MCPHandler
        #         class Ping < ::MCP::Tool
        #             tool_name 'ping'
        #             description 'Ping the application instance.'
        #             def self.call(server_context:, **)
        #                 server_context[:instance].some_application_method
        #                 ::MCP::Tool::Response.new([{ type: 'text', text: 'pong' }])
        #             end
        #         end
        #         TOOLS = [Ping].freeze
        #         def self.tools; TOOLS; end
        #     end
        #
        #     class MyApp < Cuboid::Application
        #         mcp_service_for :my_service, MCPHandler
        #     end
        def mcp_service_for( name, handler )
            mcp_services[name] = handler
        end

        def mcp_services
            @mcp_services ||= {}
        end

        # Register an `MCP::Tool` subclass to ship at the top-level
        # `/mcp` endpoint, alongside `CoreTools` (`list_instances`,
        # `spawn_instance`, `kill_instance`) — i.e. NOT routed through
        # the per-instance dispatcher and not requiring an
        # `instance_id` argument. Use this for app-level catalog /
        # metadata tools the client may want to consult before
        # spawning anything.
        #
        # Example:
        #
        #     class MyApp < Cuboid::Application
        #         mcp_app_tool ListChecks
        #     end
        def mcp_app_tool( tool_class )
            mcp_app_tools << tool_class
        end

        def mcp_app_tools
            @mcp_app_tools ||= []
        end

        # Register a bearer-token validator for the MCP transport. The
        # block receives the token string and should return a truthy
        # principal (typically a User record) on success or nil/false
        # on failure. See Cuboid::MCP::Auth for the request flow.
        #
        # Without a registered validator the auth middleware passes
        # every request through — keeps smoke tests / pre-auth-layer
        # deployments simple.
        def mcp_authenticate_with( &block )
            @mcp_auth_validator = block
        end

        def mcp_auth_validator
            @mcp_auth_validator
        end

        def agent_service_for( name, service )
            agent_services[name] = service
        end

        def agent_services
            @agent_services ||= {}
        end

        def handler_for( signal, handler )
            signal_handlers[signal] = handler
        end

        def signal_handlers
            @signal_handlers ||= {}
        end

        def serialize_with( serializer)
            @serializer = serializer
        end

        def serializer
            @serializer ||= nil

            # Default to JSON for REST API compatibility.
            @serializer || JSON
        end

        def validate_options_with( handler )
            @validate_options_with = handler
        end

        def valid_options?( options )
            @validate_options_with ||= nil
            if @validate_options_with
                return instance.method( @validate_options_with ).call( options )
            end

            true
        end

        def source_location
            splits = self.to_s.split ( '::' )
            app    = splits.pop

            last_const = Object
            splits.each do |const_name|
                last_const = last_const.const_get( const_name.to_sym )
            end

            File.expand_path last_const.const_source_location( app.to_sym ).first
        end

        def spawn( type, options = {}, &block )
            const = nil

            case type
            when :instance
                const = :Instances
            when :agent
                const = :Agents
            when :scheduler
                const = :Schedulers
            when :rest
                return Processes::Manager.spawn(
                    :rest_service,
                    options.merge( options: { paths: { application: source_location } } ),
                    &block
                )
            when :mcp
                return Processes::Manager.spawn(
                    :mcp,
                    options.merge( options: { paths: { application: source_location } } ),
                    &block
                )
            end

            Processes.const_get( const ).spawn(
              options.merge( application: source_location ),
              &block
            )
        end

        def connect( info )
            info = info.my_symbolize_keys
            Processes::Instances.connect( info[:url], info[:token] )
        end

        def inherited( application )
            super

            application.prepend PrependMethods
            self.application = application
        end

        def application
            @application
        end

        def application=( app )
            @application = app
        end

        def method_missing( sym, *args, &block )
            if instance.respond_to?( sym )
                instance.send( sym, *args, &block )
            else
                super( sym, *args, &block )
            end
        end

        def respond_to?( *args )
            super || instance.respond_to?( *args )
        end

    end

    include UI::Output
    include Utilities

    prepend Support::Mixins::SpecInstances
    include Support::Mixins::Observable
    include Support::Mixins::Parts

    # {Framework} error namespace.
    #
    # All {Framework} errors inherit from and live under it.
    #
    # When I say Framework I mean the {Framework} class, not the entire Engine
    # Framework.
    #
    # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
    class Error < Cuboid::Error
    end

    def initialize
        super

        @runtime = Runtime.new
    end

    def runtime
        @runtime
    end

    def options=( opts )
        Options.application = opts
    end

    def options
        Options.application
    end

    # @return   [Hash]
    #
    #   Framework statistics:
    #
    #   *  `:runtime`       -- Application runtime in seconds.
    def statistics
        {
            runtime: @start_datetime ? (@finish_datetime || Time.now) - @start_datetime : 0,
        }
    end

    def inspect
        stats = statistics

        s = "#<#{self.class} (#{status}) "
        s << "runtime=#{stats[:runtime]} "
        s << '>'
    end

    # @return    [String]
    #   Returns the version of the framework.
    def version
        Cuboid::VERSION
    end

    def self._spec_instance_cleanup( i )
        # i.clean_up
        i.reset
    end

    def unsafe
        self
    end

    def application
        Cuboid::Application.application
    end

    def serializer
        self.class.serializer
    end

    def safe( &block )
        raise ArgumentError, 'Missing block.' if !block_given?

        begin
            block.call self
        ensure
            clean_up
            reset
        end

        nil
    end
end

end
