module Cuboid
class State

# State information for {Cuboid::Framework}.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Application

    # {Framework} error namespace.
    #
    # All {Framework} errors inherit from and live under it.
    #
    # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
    class Error < State::Error
        # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
        class StateNotSuspendable < Error
        end

        # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
        class StateNotAbortable < Error
        end

        # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
        class InvalidStatusMessage < Error
        end
    end

    # @return     [Symbol]
    attr_accessor :status

    # @return     [Bool]
    attr_accessor :running

    # @return     [Array<String>]
    attr_reader    :status_messages

    attr_accessor  :runtime

    def initialize
        @running = false
        @pre_pause_status = nil

        @pause_signals = Set.new

        @status_messages = []
    end

    def statistics
        {
          runtime: !!@runtime
        }
    end

    # @return   [Hash{Symbol=>String}]
    #   All possible {#status_messages} by type.
    def available_status_messages
        {
            suspending:        'Will suspend as soon as the current page is audited.',
            saving_snapshot:   'Saving snapshot at: %s',
            snapshot_location: 'Snapshot location: %s',
            aborting:          'Aborting the scan.',
            timed_out:         'Scan timed out.'
        }
    end

    # Sets a message as {#status_messages}.
    #
    # @param    (see #add_status_message)
    # @return   (see #add_status_message)
    def set_status_message( *args )
        clear_status_messages
        add_status_message( *args )
    end

    # Pushes a message to {#status_messages}.
    #
    # @param    [String, Symbol]    message
    #   Status message. If `Symbol`, it will be grabbed from
    #   {#available_status_messages}.
    # @param    [String, Numeric]    sprintf
    #   `sprintf` arguments.
    def add_status_message( message, *sprintf )
        if message.is_a? Symbol
            if !available_status_messages.include?( message )
                fail Error::InvalidStatusMessage,
                     "Could not find status message for: '#{message}'"
            end

            message = available_status_messages[message] % sprintf
        end

        @status_messages << message.to_s
    end

    # Clears {#status_messages}.
    def clear_status_messages
        @status_messages.clear
    end

    def running?
        !!@running
    end

    def timed_out
        @status = :timed_out
        nil
    end

    def timed_out?
        @status == :timed_out
    end

    # @return   [Bool]
    #   `true` if the abort request was successful, `false` if the system is
    #   already {#suspended?} or is {#suspending?}.
    #
    # @raise    [StateNotAbortable]
    #   When not {#running?}.
    def abort
        return false if aborting? || aborted?

        if !running?
            fail Error::StateNotAbortable, "Cannot abort idle state: #{status}"
        end

        set_status_message :aborting
        @status = :aborting
        @abort = true

        true
    end

    # @return   [Bool]
    #   `true` if a {#abort} signal is in place , `false` otherwise.
    def abort?
        !!@abort
    end

    # Signals a completed abort operation.
    def aborted
        @abort = false
        @status = :aborted
        nil
    end

    # @return   [Bool]
    #   `true` if the system has been aborted, `false` otherwise.
    def aborted?
        @status == :aborted
    end

    # @return   [Bool]
    #   `true` if the system is being aborted, `false` otherwise.
    def aborting?
        @status == :aborting
    end

    # @return   [Bool]
    #   `true` if the system has completed successfully, `false` otherwise.
    def done?
        @status == :done
    end

    # @param    [Bool]  block
    #   `true` if the method should block until a suspend has completed,
    #   `false` otherwise.
    #
    # @return   [Bool]
    #   `true` if the suspend request was successful, `false` if the system is
    #   already {#suspended?} or is {#suspending?}.
    #
    # @raise    [StateNotSuspendable]
    #   When {#paused?} or {#pausing?}.
    def suspend
        return false if suspending? || suspended?

        if paused? || pausing?
            fail Error::StateNotSuspendable, 'Cannot suspend a paused state.'
        end

        if !running?
            fail Error::StateNotSuspendable, "Cannot suspend idle state: #{status}"
        end

        set_status_message :suspending
        @status = :suspending
        @suspend = true

        true
    end

    # @return   [Bool]
    #   `true` if an {#abort} signal is in place , `false` otherwise.
    def suspend?
        !!@suspend
    end

    # Signals a completed suspension.
    def suspended
        @suspend = false
        @status = :suspended
        nil
    end

    # @return   [Bool]
    #   `true` if the system has been suspended, `false` otherwise.
    def suspended?
        @status == :suspended
    end

    # @return   [Bool]
    #   `true` if the system is being suspended, `false` otherwise.
    def suspending?
        @status == :suspending
    end

    # @param    [Bool]  block
    #   `true` if the method should block until the pause has completed,
    #   `false` otherwise.
    #
    # @return   [TrueClass]
    #   Pauses the framework on a best effort basis, might take a while to take
    #   effect.
    def pause
        @pre_pause_status ||= @status if !paused? && !pausing?

        if !paused?
            @status = :pausing
        end

        @pause_signals << :nil

        paused if !running?
        true
    end

    # Signals that the system has been paused..
    def paused
        clear_status_messages
        @status = :paused
    end

    # @return   [Bool]
    #   `true` if the framework is paused.
    def paused?
        @status == :paused
    end

    # @return   [Bool]
    #   `true` if the system is being paused, `false` otherwise.
    def pausing?
        @status == :pausing
    end

    # @return   [Bool]
    #   `true` if the framework should pause, `false` otherwise.
    def pause?
        @pause_signals.any?
    end

    # Resumes a paused system
    #
    # @return   [Bool]
    #   `true` if the system is resumed, `false` if there are more {#pause}
    #   signals pending.
    def resume
        @status = :resuming
        @pause_signals.clear

        true
    end

    def resumed
        @status = @pre_pause_status
        @pre_pause_status = nil

        true
    end

    def dump( directory )
        FileUtils.mkdir_p( directory )

        d = Cuboid::Application.serializer.dump( @runtime )
        IO.binwrite( "#{directory}/runtime", d )
    end

    def self.load( directory )
        application = new
        application.runtime = Cuboid::Application.serializer.load( IO.binread( "#{directory}/runtime" ) )
        application
    end

    def clear
        @pause_signals.clear

        @running = false
        @pre_pause_status = nil

        @runtime = nil
    end

end

end
end
