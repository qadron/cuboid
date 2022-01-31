require_relative 'mock_app/test_service'

class MockApp < Cuboid::Application

    # This app is going to be using a max of 2 threads.
    provision_cores  2
    # This app is going to be using a max of 200MB of RAM.
    provision_memory 200 * 1024 * 1024
    # This app is going to be using a max of 2GB of disk space.
    provision_disk   2   * 1024 * 1024 * 1024

    validate_options_with :do_validate_options

    # Register event handlers.
    handler_for :pause,   :do_pause
    handler_for :resume,  :do_resume
    handler_for :suspend, :do_suspend
    handler_for :restore, :do_restore
    handler_for :abort,   :do_abort

    # RPC, report and snapshot file.
    serialize_with Marshal

    agent_service_for :test_service, TestService

    # Execution entry point.
    def run
        ap __method__
        report 'My results.'

        sleep 5
    end

    def do_validate_options( options )
        return true if !options.is_a?( Hash )
        !options.include?( 'invalid' )
    end

    def do_pause
        ap __method__
    end

    def do_resume
        ap __method__
    end

    def do_suspend
        # Write pending state and data to Cuboid::Data::Application.
        ap __method__
    end

    def do_restore
        # Restore special state and data from Cuboid::Data::Application.
        ap __method__
    end

    def do_abort
        ap __method__
    end

end
