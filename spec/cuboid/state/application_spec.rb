require 'spec_helper'

describe Cuboid::State::Application do

    subject { described_class.new }
    before(:each) { subject.clear }

    let(:dump_directory) do
        "#{Dir.tmpdir}/framework-#{Cuboid::Utilities.generate_token}"
    end

    describe '#status_messages' do
        it 'returns the assigned status messages' do
            message = 'Hey!'
            subject.set_status_message message
            expect(subject.status_messages).to eq([message])
        end

        context 'by defaults' do
            it 'returns an empty array' do
                expect(subject.status_messages).to eq([])
            end
        end
    end

    describe '#set_status_message' do
        it 'sets the #status_messages to the given message' do
            message = 'Hey!'
            subject.set_status_message message
            subject.set_status_message message
            expect(subject.status_messages).to eq([message])
        end
    end

    describe '#add_status_message' do
        context 'when given a message of type' do
            context 'String' do
                it 'pushes it to #status_messages' do
                    message = 'Hey!'
                    subject.add_status_message message
                    subject.add_status_message message
                    expect(subject.status_messages).to eq([message, message])
                end
            end

            context 'Symbol' do
                context 'and it exists in #available_status_messages' do
                    it 'pushes the associated message to #status_messages' do
                        subject.add_status_message :suspending
                        expect(subject.status_messages).to eq([subject.available_status_messages[:suspending]])
                    end
                end

                context 'and it does not exist in #available_status_messages' do
                    it "raises #{described_class::Error::InvalidStatusMessage}" do
                        expect do
                            subject.add_status_message :stuff
                        end.to raise_error described_class::Error::InvalidStatusMessage
                    end
                end

                context 'when given sprintf arguments' do
                    it 'uses them to fill in the placeholders' do
                        location = '/blah/stuff.ses'
                        subject.add_status_message :snapshot_location, location
                        expect(subject.status_messages).to eq([subject.available_status_messages[:snapshot_location] % location])
                    end
                end
            end
        end
    end

    describe '#statistics' do
        let(:statistics) { subject.statistics }
    end

    describe '#running=' do
        it 'sets #running' do
            expect(subject.running).to be_falsey

            subject.running = true
            expect(subject.running).to be_truthy
        end
    end

    describe '#running?' do
        context 'when #running is true' do
            it 'returns true' do
                subject.running = true
                expect(subject).to be_running
            end
        end

        context 'when #running is false' do
            it 'returns false' do
                subject.running = false
                expect(subject).not_to be_running
            end
        end
    end

    describe '#suspend' do
        context 'when #running?' do
            before(:each) { subject.running = true }

            context 'when non-blocking' do
                it 'sets the #status to :suspending' do
                    subject.suspend
                    expect(subject.status).to eq(:suspending)
                end

                it 'sets the status message to :suspending' do
                    subject.suspend
                    expect(subject.status_messages).to eq(
                        [subject.available_status_messages[:suspending]]
                    )
                end

                it 'returns true' do
                    expect(subject.suspend).to be_truthy
                end
            end

            context 'when already #suspending?' do
                it 'returns false' do
                    expect(subject.suspend).to be_truthy
                    expect(subject).to be_suspending
                    expect(subject.suspend).to be_falsey
                end
            end

            context 'when already #suspended?' do
                it 'returns false' do
                    expect(subject.suspend).to be_truthy
                    subject.suspended
                    expect(subject).to be_suspended

                    expect(subject.suspend).to be_falsey
                end
            end

            context 'when #pausing?' do
                it "raises #{described_class::Error::StateNotSuspendable}" do
                    subject.pause

                    expect{ subject.suspend }.to raise_error described_class::Error::StateNotSuspendable
                end
            end

            context 'when #paused?' do
                it "raises #{described_class::Error::StateNotSuspendable}" do
                    subject.pause
                    subject.paused

                    expect{ subject.suspend }.to raise_error described_class::Error::StateNotSuspendable
                end
            end
        end

        context 'when not #running?' do
            it "raises #{described_class::Error::StateNotSuspendable}" do
                expect{ subject.suspend }.to raise_error described_class::Error::StateNotSuspendable
            end
        end
    end

    describe '#suspended' do
        it 'sets the #status to :suspended' do
            subject.suspended
            expect(subject.status).to eq(:suspended)
        end
    end

    describe '#suspended?' do
        context 'when #suspended' do
            it 'returns true' do
                subject.suspended
                expect(subject).to be_suspended
            end
        end

        context 'when not #suspended' do
            it 'returns false' do
                expect(subject).not_to be_suspended
            end
        end
    end

    describe '#suspending?' do
        before(:each) { subject.running = true }

        context 'while suspending' do
            it 'returns true' do
                subject.suspend
                expect(subject).to be_suspending
            end
        end

        context 'while not suspending' do
            it 'returns false' do
                expect(subject).not_to be_suspending

                subject.suspend
                subject.suspended
                expect(subject).not_to be_suspending
            end
        end
    end

    describe '#suspend?' do
        before(:each) { subject.running = true }

        context 'when a #suspend signal is in place' do
            it 'returns true' do
                subject.suspend
                expect(subject).to be_suspend
            end
        end

        context 'when a #suspend signal is not in place' do
            it 'returns false' do
                expect(subject).not_to be_suspend

                subject.suspend
                subject.suspended
                expect(subject).not_to be_suspend
            end
        end
    end

    describe '#abort' do
        context 'when #running?' do
            before(:each) { subject.running = true }

            context 'when non-blocking' do
                it 'sets the #status to :aborting' do
                    subject.abort
                    expect(subject.status).to eq(:aborting)
                end

                it 'sets the status message to :aborting' do
                    subject.abort
                    expect(subject.status_messages).to eq(
                        [subject.available_status_messages[:aborting]]
                    )
                end

                it 'returns true' do
                    expect(subject.abort).to be_truthy
                end
            end

            context 'when already #aborting?' do
                it 'returns false' do
                    expect(subject.abort).to be_truthy
                    expect(subject).to be_aborting
                    expect(subject.abort).to be_falsey
                end
            end

            context 'when already #aborted?' do
                it 'returns false' do
                    expect(subject.abort).to be_truthy
                    subject.aborted
                    expect(subject).to be_aborted

                    expect(subject.abort).to be_falsey
                end
            end
        end

        context 'when not #running?' do
            it "raises #{described_class::Error::StateNotAbortable}" do
                expect{ subject.abort }.to raise_error described_class::Error::StateNotAbortable
            end
        end
    end

    describe '#done?' do
        context 'when #status is :done' do
            it 'returns true' do
                subject.status = :done
                expect(subject).to be_done
            end
        end

        context 'when not done' do
            it 'returns false' do
                expect(subject).not_to be_done
            end
        end
    end

    describe '#aborted' do
        it 'sets the #status to :aborted' do
            subject.aborted
            expect(subject.status).to eq(:aborted)
        end
    end

    describe '#aborted?' do
        context 'when #aborted' do
            it 'returns true' do
                subject.aborted
                expect(subject).to be_aborted
            end
        end

        context 'when not #aborted' do
            it 'returns false' do
                expect(subject).not_to be_aborted
            end
        end
    end

    describe '#aborting?' do
        before(:each) { subject.running = true }

        context 'while aborting' do
            it 'returns true' do
                subject.abort
                expect(subject).to be_aborting
            end
        end

        context 'while not aborting' do
            it 'returns false' do
                expect(subject).not_to be_aborting

                subject.abort
                subject.aborted
                expect(subject).not_to be_aborting
            end
        end
    end

    describe '#abort?' do
        before(:each) { subject.running = true }

        context 'when a #abort signal is in place' do
            it 'returns true' do
                subject.abort
                expect(subject).to be_abort
            end
        end

        context 'when a #abort signal is not in place' do
            it 'returns false' do
                expect(subject).not_to be_abort

                subject.abort
                subject.aborted
                expect(subject).not_to be_abort
            end
        end
    end

    describe '#timed_out' do
        it 'sets the #status to :timed_out' do
            subject.timed_out
            expect(subject.status).to eq(:timed_out)
        end
    end

    describe '#timed_out?' do
        context 'when a #timed_out signal is in place' do
            it 'returns true' do
                subject.timed_out
                expect(subject).to be_timed_out
            end
        end

        context 'when a #timed_out signal is not in place' do
            it 'returns false' do
                expect(subject).not_to be_timed_out
            end
        end
    end

    describe '#pause' do
        context 'when #running?' do
            before(:each) { subject.running = true }

            context 'when non-blocking' do
                it 'sets the #status to :pausing' do
                    subject.pause
                    expect(subject.status).to eq(:pausing)
                end

                it 'returns true' do
                    expect(subject.pause).to be_truthy
                end
            end
        end

        context 'when not #running?' do
            before(:each) { subject.running = false }

            it 'sets the #status directly to :paused' do
                t = Thread.new do
                    sleep 1
                    subject.paused
                end

                time = Time.now
                subject.pause
                expect(subject.status).to eq(:paused)
                expect(Time.now - time).to be < 1
                t.join
            end
        end
    end

    describe '#paused' do
        it 'sets the #status to :paused' do
            subject.paused
            expect(subject.status).to eq(:paused)
        end
    end

    describe '#pausing?' do
        before(:each) { subject.running = true }

        context 'while pausing' do
            it 'returns true' do
                subject.pause
                expect(subject).to be_pausing
            end
        end

        context 'while not pausing' do
            it 'returns false' do
                expect(subject).not_to be_pausing

                subject.pause
                subject.paused
                expect(subject).not_to be_pausing
            end
        end
    end

    describe '#pause?' do
        context 'when a #pause signal is in place' do
            it 'returns true' do
                subject.pause
                expect(subject).to be_pause
            end
        end

        context 'when a #pause signal is not in place' do
            it 'returns false' do
                expect(subject).not_to be_pause

                subject.pause
                subject.paused
                subject.resume
                expect(subject).not_to be_pause
            end
        end
    end

    describe '#resume' do
        before(:each) { subject.running = true }

        it 'removes #pause signals' do
            subject.pause
            subject.resume
            expect(subject).not_to be_paused
        end

        it 'sets status to :resuming' do
            subject.status = :my_status

            subject.pause
            subject.paused
            expect(subject.status).to be :paused

            subject.resume
            expect(subject.status).to be :resuming
        end

        context 'when called before a #pause signal has been sent' do
            it '#pause? returns false' do
                subject.pause
                subject.resume
                expect(subject).not_to be_pause
            end

            it '#paused? returns false' do
                subject.pause
                subject.resume
                expect(subject).not_to be_paused
            end
        end

        context 'when there are no more signals' do
            it 'returns true' do
                subject.pause
                subject.paused

                expect(subject.resume).to be_truthy
            end
        end

        context 'when there are more signals' do
            it 'returns true' do
                subject.pause
                subject.pause
                subject.paused

                expect(subject.resume).to be_truthy
            end
        end
    end

    describe '#resumed' do
        it 'restores the previous #status' do
            subject.status = :my_status

            subject.pause
            subject.paused
            expect(subject.status).to be :paused

            subject.resumed
            expect(subject.status).to be :my_status
        end

    end

    describe '#dump' do
    end

    describe '.load' do
    end

    describe '#clear' do
    end
end
