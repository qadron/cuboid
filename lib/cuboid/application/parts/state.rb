module Cuboid
class Application
module Parts

# Provides access to {Cuboid::State::Application} and helpers.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
module State

    def self.included( base )
        base.extend ClassMethods
    end

    module ClassMethods

        # @param   [String]    ses
        #   Path to an `.ses.` (Cuboid Application Snapshot) file created by
        #   {#suspend}.
        #
        # @return   [Application]
        #   Restored instance.
        def restore!( ses, &block )
            f = self.instance.restore!( ses )
            block_given? ? f.safe( &block ) : f
        end

        # @note You should first reset {Cuboid::Options}.
        #
        # Resets everything and allows the framework environment to be re-used.
        def reset
            Cuboid::State.clear
            Cuboid::Data.clear
            Cuboid::Snapshot.reset

            Cuboid::Support::Database::Base.reset
            Cuboid::System.reset
        end
    end

    def initialize
        super

        state.status = :ready
    end

    # @return   [String]
    #   Provisioned {#suspend} dump file for this instance.
    def snapshot_path
        return @state_archive if @state_archive

        default_filename =
            "Cuboid #{Time.now.to_s.gsub( ':', '_' )} " <<
                "#{generate_token}.#{Snapshot::EXTENSION}"

        location = Cuboid::Options.snapshot.path

        if !location
            location = default_filename
        elsif File.directory? location
            location += "/#{default_filename}"
        end

        @state_archive ||= File.expand_path( location )
    end

    # @note Prefer this from {.reset} if you already have an instance.
    # @note You should first reset {Cuboid::Options}.
    #
    # Resets everything and allows the framework to be re-used.
    def reset
        @state_archive   = nil
        @cleaned_up      = false
        @start_datetime  = nil
        @finish_datetime = nil

        # This needs to happen before resetting the other components so they
        # will be able to put in their hooks.
        self.class.reset

        clear_observers
    end

    # @return   [State::Application]
    def state
        Cuboid::State.application
    end

    # @param   [String]    ses
    #   Path to an `.ses.` (Cuboid Application Snapshot) file created by {#suspend}.
    #
    # @return   [Application]
    #   Restored instance.
    def restore!( ses )
        if handler = self.class.signal_handlers[:restore]
            method( handler ).call
        end

        Snapshot.load ses

        state.status = :restored

        self
    end

    # @return   [Array<String>]
    #   Messages providing more information about the current {#status} of
    #   the framework.
    def status_messages
        state.status_messages
    end

    # @return   [Symbol]
    #   Status of the instance, possible values are (in order):
    #
    #   * `:ready` -- {#initialize Initialised} and waiting for instructions.
    #   * `:preparing` -- Getting ready to start.
    #   * `:pausing` -- The instance is being {#pause paused} (if applicable).
    #   * `:paused` -- The instance has been {#pause paused} (if applicable).
    #   * `:suspending` -- The instance is being {#suspend suspended} (if applicable).
    #   * `:suspended` -- The instance has being {#suspend suspended} (if applicable).
    #   * `:cleanup` -- The instance is done and cleaning up.
    #   * `:aborted` -- The scan has been {Application::Parts::State#abort}, you can grab the
    #       report and shutdown.
    #   * `:done` -- The scan has completed, you can grab the report and shutdown.
    #   * `:timed_out` -- The scan was aborted due to a time-out..
    def status
        state.status
    end

    # @return   [Bool]
    #   `true` if the framework is running, `false` otherwise. This is `true`
    #   even if the scan is {#paused?}.
    def running?
        state.running?
    end

    # @return   [Bool]
    #   `true` if the framework is paused, `false` otherwise.
    def paused?
        state.paused?
    end

    # @return   [Bool]
    #   `true` if the framework has been instructed to pause (i.e. is in the
    #   process of being paused or has been paused), `false` otherwise.
    def pause?
        state.pause?
    end

    # @return   [Bool]
    #   `true` if the framework is in the process of pausing, `false` otherwise.
    def pausing?
        state.pausing?
    end

    # @return   (see Cuboid::State::Application#done?)
    def done?
        state.done?
    end

    # @note Each call from a unique caller is counted as a pause request
    #   and in order for the system to resume **all** pause callers need to
    #   {#resume} it.
    #
    # Pauses the framework on a best effort basis.
    #
    # @return   [Integer]
    #   ID identifying this pause request.
    def pause!
        state.pause

        if handler = self.class.signal_handlers[:pause]
            method( handler ).call
        end

        state.paused

        nil
    end

    # @return   [Bool]
    #   `true` if the {Application#run} has been aborted, `false` otherwise.
    def aborted?
        state.aborted?
    end

    # @return   [Bool]
    #   `true` if the framework has been instructed to abort (i.e. is in the
    #   process of being aborted or has been aborted), `false` otherwise.
    def abort?
        state.abort?
    end

    # @return   [Bool]
    #   `true` if the framework is in the process of aborting, `false` otherwise.
    def aborting?
        state.aborting?
    end

    # Aborts the {Application#run} on a best effort basis.
    def abort!
        state.abort

        if handler = self.class.signal_handlers[:abort]
            method( handler ).call
        end

        state.aborted
    end

    def resume!
        state.resume

        if handler = self.class.signal_handlers[:resume]
            method( handler ).call
        end

        state.resumed
    end

    # Writes a {Snapshot.dump} to disk and aborts the scan.
    #
    # @return   [String,nil]
    #   Path to the state file `wait` is `true`, `nil` otherwise.
    def suspend!
        state.suspend

        if handler = self.class.signal_handlers[:suspend]
            method( handler ).call
        end

        suspend_to_disk
        state.suspended

        snapshot_path
    end

    # @return   [Bool]
    #   `true` if the system is in the process of being suspended, `false`
    #   otherwise.
    def suspend?
        state.suspend?
    end

    # @return   [Bool]
    #   `true` if the system has been suspended, `false` otherwise.
    def suspended?
        state.suspended?
    end

    private

    def wait_if_paused
        state.paused if pause?
        sleep 0.2 while pause? && !abort?
    end

    def suspend_to_disk
        state.set_status_message :saving_snapshot, snapshot_path
        Snapshot.dump( snapshot_path )
        state.clear_status_messages

        clean_up

        state.set_status_message :snapshot_location, snapshot_path
        print_info status_messages.first
        state.suspended
    end

end

end
end
end
