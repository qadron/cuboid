require 'json'
require 'spec_helper'
require "#{fixtures_path}/mock_app"

describe 'Cuboid::RPC::Server::Instance' do
    let(:subject) { instance_spawn( application: "#{fixtures_path}/mock_app.rb", daemonize: true ) }

    it 'supports UNIX sockets', if: Raktr.supports_unix_sockets? do
        socket = "#{Dir.tmpdir}/cuboid-instance-#{Cuboid::Utilities.generate_token}"
        subject = instance_spawn(
          socket:      socket,
          application: "#{fixtures_path}/mock_app.rb",
          daemonize: true
        )

        expect(subject.url).to eq(socket)
        expect(subject.alive?).to be_truthy
    end

    describe '#application' do
        it 'returns the application name' do
            expect(subject.application).to eq 'MockApp'
        end
    end

    describe '#snapshot_path' do
        it 'returns the path to the future/current snapshot' do
            subject.run

            Timeout.timeout 5 do
                sleep 1 while !subject.running?
            end

            expect(subject.snapshot_path).to end_with '.csf'
        end
    end

    describe '#suspend!' do
        it 'suspends the Instance to disk' do
            subject.run

            Timeout.timeout 5 do
                sleep 1 while !subject.running?
            end

            subject.suspend!

            Timeout.timeout 5 do
                sleep 1 while !subject.suspended?
            end

            expect(File.exist?( subject.snapshot_path )).to be_truthy
        end
    end

    describe '#suspended?' do
        context 'when the Instance has not been suspended' do
            it 'returns false' do
                expect(subject.suspended?).to be_falsey
            end
        end

        context 'when the Instance has been suspended' do
            it 'returns true' do
                subject.run

                Timeout.timeout 5 do
                    sleep 1 while !subject.running?
                end

                subject.suspend!

                Timeout.timeout 5 do
                    sleep 1 while !subject.suspended?
                end

                expect(subject.suspended?).to be_truthy
            end
        end
    end

    describe '#busy?' do
        context 'when the Instance is not running' do
            it 'returns false' do
                expect(subject.busy?).to be_falsey
            end
        end

        context 'when the Instance is running' do
            it 'returns true' do
                subject.run
                expect(subject.busy?).to be_truthy
            end
        end
    end

    describe '#restore!' do
        it 'suspends the Instance to disk' do
            subject.run

            options = subject.generate_report.options

            subject.suspend!

            Timeout.timeout 5 do
                sleep 1 while subject.status != :suspended
            end

            snapshot_path = subject.snapshot_path
            subject.shutdown

            subject = instance_spawn( daemonize: true )
            subject.restore! snapshot_path

            sleep 1 while subject.status != :done

            expect(subject.generate_report.options).to eq(options)
        end
    end

    describe '#errors' do
        before(:each) do
            subject.error_test error
        end
        let(:error) { "My error #{rand(9999)}" }

        context 'when no argument has been provided' do
            it 'returns all logged errors' do
                expect(subject.errors.last).to end_with error
            end
        end

        context 'when a start line-range has been provided' do
            it 'returns all logged errors after that line' do
                initial_errors = subject.errors
                errors = subject.errors( 10 )

                expect(initial_errors[10..-1]).to eq(errors)
            end
        end
    end

    describe '#error_logfile' do
        before(:each) do
            subject.error_test error
        end
        let(:error) { "My error #{rand(9999)}" }

        it 'returns the path to the error logfile' do
            errors = IO.read( subject.error_logfile )

            subject.errors.each do |error|
                expect(errors).to include error
            end
        end
    end

    describe '#alive?' do
        it 'returns true' do
            expect(subject.alive?).to eq(true)
        end
    end

    describe '#paused?' do
        context 'when not paused' do
            it 'returns false' do
                expect(subject.paused?).to be_falsey
            end
        end
        context 'when paused' do
            it 'returns true' do
                subject.run

                subject.pause!
                Timeout.timeout 5 do
                    sleep 1 while !subject.paused?
                end

                expect(subject.paused?).to be_truthy
            end
        end
    end

    describe '#resume!' do
        it 'resumes the Instance' do
            subject.run

            subject.pause!
            Timeout.timeout 5 do
                sleep 1 while !subject.paused?
            end

            expect(subject.paused?).to be_truthy
            expect(subject.resume!).to be_truthy

            Timeout.timeout 5 do
                sleep 1 while subject.paused?
            end

            expect(subject.paused?).to be_falsey
        end
    end

    describe '#abort_and_generate_report' do
        it "cleans-up and returns the report as #{Cuboid::Report}" do
            subject.run

            expect(subject.abort_and_generate_report).to be_kind_of Cuboid::Report
        end
    end

    describe '#status' do
        context 'after initialization' do
            it 'returns :ready' do
                expect(subject.status).to eq(:ready)
            end
        end

        context 'after #run has been called' do
            it 'returns :running' do
                subject.run

                sleep 2
                expect(subject.status).to eq(:running)
            end
        end

        context 'once the Instance has completed' do
            it 'returns :done' do
                subject.run

                sleep 1 while subject.busy?
                expect(subject.status).to eq(:done)
            end
        end
    end

    describe '#run' do
        context 'on invalid options' do
            it 'raises ArgumentError' do
                expect do
                    subject.run invalid: :stuff
                end.to raise_error Toq::Exceptions::RemoteException
            end
        end

        it 'configures and starts a job' do
            expect(subject.busy?).to  be false
            expect(subject.status).to be :ready

            subject.run

            # if a run in already running it should just bail out early
            expect(subject.run).to be_falsey

            sleep 1 while subject.busy?

            expect(subject.busy?).to  be false
            expect(subject.status).to be :done
        end
    end

    describe '#progress' do
        before( :each ) do
            subject.run
            sleep 1 while subject.busy?
        end

        it 'returns progress information' do
            p = subject.progress
            expect(p[:busy]).to   be false
            expect(p[:status]).to be :done
            expect(p[:statistics]).to  be_any

            expect(p[:seed]).not_to be_empty
        end

        describe ':without' do
            describe ':statistics' do
                it 'includes statistics' do
                    expect(subject.progress(
                        without: :statistics
                    )).not_to include :statistics
                end
            end

            context 'with an array of things to be excluded'  do
                it 'excludes those things'
            end
        end

        describe ':with' do
            context 'with an array of things to be included'  do
                it 'includes those things'
            end
        end
    end

    describe '#shutdown' do
        it 'shuts-down the instance' do
            expect(subject.shutdown).to be_truthy
            sleep 4

            expect { subject.alive? }.to raise_error Toq::Exceptions::ConnectionError
        end
    end

end
