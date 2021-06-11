require 'cuboid'

require_relative 'my_app/rpc_api'
require_relative 'my_app/rest_api'
require_relative 'my_app/aggregator'

class MyApp < Cuboid::Application

    # This app is going to be using a max of 2 threads.
    provision_cores  2
    # This app is going to be using a max of 1MB of RAM.
    provision_memory 1 * 1024 * 1024
    # This app is going to be using a max of 1MB of disk space.
    provision_disk   1 * 1024 * 1024

    validate_options_with :do_validate_options

    # Register event handlers in case any events require special clean-up,
    # or some such, prior to completing -- or to actually make them happen.
    #
    # Pause the system.
    handler_for :pause,   :do_pause
    # Get going again; simple unpause or something more elaborate?
    handler_for :resume,  :do_resume
    # A snapshot of the runtime is about to be captured, quickly store any
    # runtime data that are out and about (local vars etc.) in their proper place.
    handler_for :suspend, :do_suspend
    # This run comes from a restored snapshot, so, something or other.
    handler_for :restore, :do_restore
    # Quit everything and cleanup.
    handler_for :abort,   :do_abort

    # Setup an Instance RPC service to expose a custom API.
    instance_service_for   :custom, RPCAPI

    # Hook-up to the REST service to expose a custom API.
    rest_service_for       :custom, RESTAPI

    # Hook-up to the Dispatcher to expose a custom RPC API.
    dispatcher_service_for :custom, Aggregator

    # RPC, report data, options and runtime snapshot.
    #
    # Basically, everything that is app-centric can be freed from the underlying
    # Cuboid choices if need be.
    #
    # For example, if passing existing _native_ objects, or want to create
    # your own, specifying a serializer of your choice in order to handle them
    # would be quite freeing.
    #
    # In essence, custom/special objects can be passed back and forth with ease.
    serialize_with Marshal

    attr_reader :my_attr

    # Execution entry point.
    def run
        ap __method__

        @my_attr = 'foobar'

        # What was passed to Instance#run.
        # Note how Hash keys are now strings.
        ap options['id']

        # Store and retrieve arbitrary state data here.
        # Will be dumped to a snapshot file when suspended and restored after a
        # state restoration.
        runtime.state = {
            defining: { data: :here }
        }

        ap runtime.state[:defining]
        # {
        #     :data => :here
        # }

        # Store and retrieve arbitrary workload data here if you must.
        # Will be dumped to a snapshot file when suspended and restored after a
        # state restoration.
        runtime.data = {
            workload: { storage: :here }
        }

        ap runtime.data[:workload]
        # {
        #     :storage => :here
        # }

        # Store report data for this run, in this case ping pong some of the config.
        # This will later be encapsulated and accessed via the Report object via
        # #generate_report.
        report options['id']
    end

    # @return   [Boolean]   `true` upon valid options, `false` otherwise.
    def do_validate_options( options )
        options.include? 'id'
    end

    def do_pause
        ap __method__
    end

    def do_resume
        ap __method__
    end

    def do_suspend
        ap __method__
    end

    def do_restore
        ap __method__
    end

    def do_abort
        ap __method__
    end

end
