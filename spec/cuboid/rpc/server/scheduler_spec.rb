require 'spec_helper'

require "#{Cuboid::Options.paths.lib}/rpc/server/scheduler"

describe Cuboid::RPC::Server::Scheduler do
    before( :each ) do
        Cuboid::Options.system.max_slots        = 10
        Cuboid::Options.scheduler.ping_interval = 0.5
    end

    subject { scheduler_spawn( application: "#{fixtures_path}/mock_app.rb" ) }
    let(:options) { {} }

    context 'when there are queued scans' do
        it 'performs them' do
            expect(subject.completed).to be_empty

            ids = []
            3.times do
                ids << subject.push( options )
            end

            sleep 1 while subject.completed.size != 3

            expect(subject.completed.keys.sort).to eq ids.sort

            subject.completed.values.each do |report|
                expect do
                    Cuboid::Report.load( report )
                end.to_not raise_error
            end
        end

        it 'stores the reports' do
            subject.push( options )
            sleep 0.1 while subject.completed.empty?

            expect(subject.completed.values.first).to start_with Cuboid::Options.paths.reports
        end

        it 'shuts down the Instance' do
            subject.push( options )
            sleep 0.1 while subject.running.empty?

            pid = subject.running.values.first['pid']
            expect(Cuboid::Processes::Manager.alive?( pid )).to be true

            sleep 0.1 while subject.completed.empty?
            sleep 2

            expect(Cuboid::Processes::Manager.alive?( pid )).to be false
        end
    end

    context 'when a Dispatcher has been set' do
        subject { Cuboid::Processes::Schedulers.spawn dispatcher: dispatcher.url }
        let(:dispatcher) do
            Cuboid::Processes::Dispatchers.spawn( application: "#{fixtures_path}/mock_app.rb" )
        end

        it 'gets Instances from it' do
            expect(dispatcher.finished_instances).to be_empty

            subject.push( options )
            sleep 0.1 while subject.completed.empty?
            sleep 2

            expect(dispatcher.finished_instances).to be_any
        end

        it 'sets OptionGroups::Scheduler#url' do
            id = subject.push( options )
            sleep 0.1 while subject.running.empty?

            info = subject.running[id]
            expect(instance_connect( info['url'], info['token'] ).scheduler_url).to eq subject.url
        end

        context 'but becomes unavailable' do
            it 'does not consume the queue' do
                subject

                Cuboid::Processes::Dispatchers.killall
                sleep 3

                expect(subject.size).to be 0

                subject.push( options )
                sleep 5

                expect(subject.size).to be 1
                expect(subject.errors.join("\n")).to include "Failed to contact Dispatcher at: #{dispatcher.url}"
            end
        end
    end

    describe '#alive?' do
        it 'returns true' do
            expect(subject.alive?).to be_truthy
        end
    end

    describe '#empty?' do
        context 'when the queue is empty' do
            it 'returns true' do
                expect(subject.empty?).to be_truthy
            end
        end

        context 'when the queue is not empty' do
            it 'returns true' do
                subject.push( options )
                expect(subject.empty?).to be_falsey
            end
        end
    end

    describe '#any?' do
        context 'when the queue is empty' do
            it 'returns false' do
                expect(subject.any?).to_not be_truthy
            end
        end

        context 'when the queue is not empty' do
            it 'returns true' do
                subject.push( options )
                expect(subject.any?).to be_truthy
            end
        end
    end

    describe '#size' do
        it 'returns the queue size' do
            expect(subject.size).to be 0
            subject.push( options )
            expect(subject.size).to be 1
        end
    end

    describe '#list' do
        it 'returns the queue entries grouped and sorted by priority' do
            medium = subject.push( options, priority: 0 )
            low    = subject.push( options, priority: -1 )
            high   = subject.push( options, priority: 1 )

            expect(subject.list).to eq(
                1  => [high],
                0  => [medium],
                -1 => [low],
            )
        end
    end

    describe '#running' do
        it 'returns running scans' do
            expect(subject.running).to be_empty

            ids = []
            3.times do
                ids << subject.push( options )
            end
            sleep 0.1 while subject.running.empty?

            expect(subject.running.keys & ids).to be_any
            expect(subject.running.values.first).to include 'url'
            expect(subject.running.values.first).to include 'token'
            expect(subject.running.values.first).to include 'pid'
        end
    end

    describe '#detach' do
        it 'detaches a running scan' do
            id = subject.push( options )
            sleep 0.1 while subject.running.empty?

            info = subject.detach( id )

            expect(info.keys.sort).to eq %w(url token pid).sort

            client = instance_connect( info['url'], info['token'] )

            expect(subject.running).to be_empty

            sleep 0.1 while client.busy?
            client.shutdown
            sleep 2

            expect(subject.completed).to be_empty
            expect(subject.failed).to be_empty
        end

        it 'removes OptionGroups::Scheduler#url' do
            id = subject.push( options )
            sleep 0.1 while subject.running.empty?

            info   = subject.detach( id )
            client = instance_connect( info['url'], info['token'] )

            expect(client.scheduler_url).to be_nil
        end

        context 'when no scan with that ID is found' do
            it 'returns nil' do
                subject.push( options )
                sleep 0.1 while subject.running.empty?

                expect(subject.detach( 'id' )).to be_nil
            end
        end
    end

    describe '#attach' do
        let(:client) { instance_spawn( application: "#{fixtures_path}/mock_app.rb" ) }

        it 'attaches a running Instance to the queue' do
            expect(subject.attach( client.url, client.token )).to eq client.token

            id = client.token
            expect(subject.running).to eq(
                id => {
                    'url'   => client.url,
                    'token' => client.token,
                    'pid'   => nil
                }
            )

            client.run( options )
            sleep 0.1 while subject.completed.empty?

            expect(subject.completed.keys).to eq [id]
        end

        it 'sets OptionGroups::Scheduler#url' do
            expect(client.scheduler_url).to be_nil

            subject.attach( client.url, client.token )

            client.run( options )
            sleep 0.1 while subject.running.empty?

            expect(client.scheduler_url).to eq subject.url
        end

        context 'when the Instance is already attached to a Scheduler' do
            it 'returns false' do
                expect(client.scheduler_url).to be_nil

                subject.attach( client.url, client.token )
                expect(client.scheduler_url).to eq subject.url

                q = scheduler_spawn

                expect(q.attach( client.url, client.token )).to be_falsey
                expect(client.scheduler_url).to eq subject.url
            end
        end

        context 'when the Instance could not be accessed' do
            it 'returns nil' do
                expect(subject.attach( '127.0.0.1:3333', 'fdfdfd' )).to be_nil
            end
        end
    end

    describe '#completed' do
        it 'returns completed scans' do
            expect(subject.completed).to be_empty

            ids = []
            3.times do
                ids << subject.push( options )
            end
            sleep 0.1 while subject.completed.size != 3

            expect(subject.completed.keys.sort).to eq ids.sort

            subject.completed.values.each do |report|
                expect do
                    Cuboid::Report.load( report )
                end.to_not raise_error
            end
        end
    end

    describe '#failed' do
        it 'returns failed scans' do
            expect(subject.completed).to be_empty

            id = subject.push( options )
            sleep 0.1 while subject.running.empty?

            process_kill( subject.running.values.first['pid'] )
            sleep 0.1 while subject.failed.empty?

            expect(subject.failed[id]['error']).to eq 'Arachni::RPC::Exceptions::ConnectionError'
            expect(subject.failed[id]['description']).to include 'Connection closed'
        end
    end

    describe '#get' do
        it "returns a queued scan's info" do
            info = subject.get( subject.push( options ) )
            expect(info).to eq(
                'options' => options,
                'priority' => 0
            )
        end

        context 'when no scan matching the ID is queued' do
            it 'returns nil' do
                expect(subject.get( '1' )).to be_nil
            end
        end
    end

    describe '#push' do
        it 'queues a scan' do
            subject.push( options )
            expect(subject.any?).to be_truthy
        end

        it 'returns an ID' do
            id = subject.push( options )
            expect(subject.get( id )).to be_truthy
        end

        it 'sets OptionGroups::Scheduler#url' do
            id  = subject.push( options )
            sleep 0.1 while subject.running.empty?

            info   = subject.running[id]
            client = instance_connect( info['url'], info['token'] )

            expect(client.scheduler_url).to eq subject.url
        end

        context 'on invalid options' do
            it 'raises ArgumentError' do
                expect do
                    subject.push invalid: :test
                end.to raise_error Arachni::RPC::Exceptions::RemoteException
            end
        end

        context 'when no priority is specified' do
            it 'uses 0' do
                id = subject.push( options )
                expect(subject.get( id )['priority']).to be 0
            end
        end

        context 'when priority is specified' do
            it 'uses it' do
                id = subject.push( options, priority: 1 )
                expect(subject.get( id )['priority']).to be 1
            end
        end
    end

    describe '#remove' do
        it 'removes a scan from the queue' do
            id = subject.push( options )
            expect(subject.remove( id )).to be true
        end

        context 'when the scan does not exist' do
            it 'returns false' do
                expect(subject.remove( 'id' )).to be false
            end
        end
    end

    describe '#clear' do
        it 'clears the queue' do
            expect(subject.empty?).to be_truthy

            10.times do
                subject.push( options )
            end

            expect(subject.any?).to be_truthy

            subject.clear

            expect(subject.empty?).to be_truthy
        end
    end

    describe '#shutdown' do
        it 'shuts down the server' do
            subject.shutdown
            sleep 2

            expect do
                subject.alive?
            end.to raise_error Arachni::RPC::Exceptions::ConnectionError
        end
    end
end
