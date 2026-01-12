require 'spec_helper'
require 'fileutils'

require "#{Cuboid::Options.paths.lib}/rpc/server/agent"

describe Cuboid::RPC::Server::Agent do
    before( :each ) do
        Cuboid::Options.system.max_slots = slots
    end

    let(:instance_info_keys) { %w(token application pid url owner birthdate helpers now age) }
    let(:slots) { 3 }
    let(:subject) { agent_spawn( application: "#{fixtures_path}/mock_app.rb", daemonize: true ) }

    describe '#alive?' do
        it 'returns true' do
            expect(subject.alive?).to eq(true)
        end
    end

    describe '#preferred' do
        context 'when the agent is a grid member' do
            context 'and strategy is' do
                context :horizontal do
                    it 'returns the URL of least burdened Agent' do
                        agent_spawn( peer: subject.url, daemonize: true ).spawn( strategy: :direct )
                        agent_spawn( peer: subject.url, daemonize: true ).spawn( strategy: :direct )

                        expect(subject.preferred( :horizontal )).to eq(subject.url)
                    end
                end

                context :vertical do
                    it 'returns the URL of most burdened Agent' do
                        agent_spawn( peer: subject.url, daemonize: true ).spawn( strategy: :direct )
                        d = agent_spawn( peer: subject.url, daemonize: true )
                        d.spawn( strategy: :direct )
                        d.spawn( strategy: :direct )

                        expect(subject.preferred( :vertical )).to eq(d.url)
                    end
                end

                context :direct do
                    it 'returns the URL of this Agent'
                end

                context 'default' do
                    it 'returns the URL of least burdened Agent' do
                        agent_spawn( peer: subject.url, daemonize: true ).spawn( strategy: :direct )
                        agent_spawn( peer: subject.url, daemonize: true ).spawn( strategy: :direct )

                        expect(subject.preferred).to eq(subject.url)
                    end
                end

                context 'other' do
                    it 'returns :error_unknown_strategy' do
                        agent_spawn( peer: subject.url, daemonize: true ).spawn( strategy: :direct )
                        agent_spawn( peer: subject.url, daemonize: true ).spawn( strategy: :direct )

                        expect(subject.preferred( :blah )).to eq('error_unknown_strategy')
                    end
                end
            end

            context 'and all Agents are at max utilization' do
                before :each do
                    subject.spawn( strategy: :direct )
                end

                let(:slots) { 1 }

                it 'returns nil' do
                    agent_spawn( peer: subject.url, daemonize: true ).spawn( strategy: :direct )
                    agent_spawn( peer: subject.url, daemonize: true ).spawn( strategy: :direct )

                    expect(subject.preferred).to be_nil
                end
            end
        end

        context 'when the agent is not a grid member' do
            it 'returns the URL of the Agent' do
                expect(subject.preferred).to eq(subject.url)
            end

            context 'and it is at max utilization' do
                before :each do
                    subject.spawn( strategy: :direct )
                end

                let(:slots) { 1 }

                it 'returns nil' do
                    expect(subject.preferred).to be_nil
                end
            end
        end
    end

    describe '#handlers' do
        it 'returns an array of loaded handlers' do
            expect(subject.services.include?( 'test_service' )).to be_truthy
        end
    end

    describe '#spawn' do
        it 'does not leak Instances' do
            slots.times do
                subject.spawn
            end

            expect(subject.instances.size).to eq(slots)
        end

        it 'sets OptionGroups::Agent#url' do
            info = subject.spawn
            instance = instance_connect( info['url'], info['token'] )

            expect(instance.agent_url).to eq subject.url
        end

        context "when #{Cuboid::OptionGroups::RPC}#server_external_address has been set" do
            before :each do
                Cuboid::Options.rpc.server_external_address = address
            end

            let(:address) { '127.0.0.2' }

            it 'advertises that address' do
                expect(subject.spawn['url']).to start_with "#{address}:"
            end
        end

        context 'when not a Grid member' do
            it 'returns Instance info' do
                info = subject.spawn( owner: 'rspec' )

                %w(token application pid url owner birthdate helpers).each do |k|
                    expect(info[k]).to be_truthy
                end

                instance = instance_connect( info['url'], info['token'] )
                expect(instance.alive?).to be_truthy
            end

            it 'assigns an optional owner' do
                owner = 'blah'
                expect(subject.spawn( owner: owner )['owner']).to eq(owner)
            end

            context 'when the there are no available slots' do
                let(:slots) { 5 }
                before :each do
                    slots.times do
                        subject.spawn
                    end
                end

                it 'returns nil' do
                    expect(subject.spawn).to be nil
                end

                context 'and slots are freed' do
                    let(:free) { slots - 1 }

                    it 'returns Instance info' do
                        pids_to_free = []
                        subject.instances[0...free].each do |info|
                            pids_to_free << info['pid']
                            service = instance_connect( info['url'], info['token'] )
                            service.shutdown

                            while sleep 0.1
                                service.alive? rescue break
                            end
                        end

                        # Wait for the actual OS processes to exit, not just RPC to die
                        pids_to_free.each do |pid|
                            timeout = 50  # 5 seconds max wait
                            while sleep 0.1
                                timeout -= 1
                                break if timeout <= 0
                                break unless Cuboid::Processes::Manager.alive?(pid)
                            end
                        end

                        instances = []
                        free.times do
                            instances << subject.spawn
                        end
                        instances.compact!

                        expect(instances.size).to eq free
                        expect(subject.spawn).to be nil
                    end
                end
            end
        end

        context 'when a Grid member' do
            let(:slots) { 4 }

            context 'and strategy is' do
                context :direct do
                    it 'provides Instances from this Agent'
                end

                context :horizontal do
                    it 'provides Instances from the least burdened Agent' do
                        d1 = agent_spawn(
                          address: '127.0.0.1',
                          application: "#{fixtures_path}/mock_app.rb",
                          daemonize: true
                        )

                        3.times do
                            d1.spawn( strategy: :direct )
                        end

                        d2 = agent_spawn(
                          address:   '127.0.0.2',
                          peer: d1.url,
                          application: "#{fixtures_path}/mock_app.rb",
                          daemonize: true
                        )

                        2.times do
                            d2.spawn( strategy: :direct )
                        end

                        d3 = agent_spawn(
                          address:   '127.0.0.3',
                          peer: d1.url,
                          application: "#{fixtures_path}/mock_app.rb",
                          daemonize: true
                        )
                        d3.spawn( strategy: :direct )

                        preferred = d3.url.split( ':' ).first
                        expect(d3.spawn(strategy: :horizontal )['url'].split( ':' ).first).to eq(preferred)
                        expect(%W{127.0.0.3 127.0.0.2}).to include d1.spawn['url'].split( ':' ).first
                        expect(d2.spawn(strategy: :horizontal )['url'].split( ':' ).first).to eq(preferred)
                        expect(%W{127.0.0.1 127.0.0.2}).to include d3.spawn(strategy: :horizontal )['url'].split( ':' ).first
                        expect(%W{127.0.0.1 127.0.0.3}).to include d3.spawn(strategy: :horizontal )['url'].split( ':' ).first
                        expect(%W{127.0.0.2 127.0.0.3}).to include d1.spawn(strategy: :horizontal )['url'].split( ':' ).first
                    end
                end

                context :vertical do
                    it 'provides Instances from the most burdened Agent' do
                        d1 = agent_spawn(
                          address: '127.0.0.1',
                          application: "#{fixtures_path}/mock_app.rb",
                          daemonize: true
                        )

                        3.times do
                            d1.spawn( strategy: :direct )
                        end

                        d2 = agent_spawn(
                          address:   '127.0.0.2',
                          peer: d1.url,
                          application: "#{fixtures_path}/mock_app.rb",
                          daemonize: true
                        )

                        2.times do
                            d2.spawn( strategy: :direct )
                        end

                        d3 = agent_spawn(
                          address:   '127.0.0.3',
                          peer: d1.url,
                          application: "#{fixtures_path}/mock_app.rb",
                          daemonize: true
                        )
                        d3.spawn( strategy: :direct )

                        preferred = d1.url.split( ':' ).first
                        expect(d3.spawn( strategy: :vertical )['url'].split( ':' ).first).to eq(preferred)
                    end
                end

                context 'default' do
                    it 'provides Instances from the least burdened Agent' do
                        d1 = agent_spawn(
                          address: '127.0.0.1',
                          application: "#{fixtures_path}/mock_app.rb",
                          daemonize: true
                        )

                        3.times do
                            d1.spawn( strategy: :direct )
                        end

                        d2 = agent_spawn(
                          address:   '127.0.0.2',
                          peer: d1.url,
                          application: "#{fixtures_path}/mock_app.rb",
                          daemonize: true
                        )

                        2.times do
                            d2.spawn( strategy: :direct )
                        end

                        d3 = agent_spawn(
                          address:   '127.0.0.3',
                          peer: d1.url,
                          application: "#{fixtures_path}/mock_app.rb",
                          daemonize: true
                        )
                        d3.spawn( strategy: :direct )

                        preferred = d3.url.split( ':' ).first
                        expect(d3.spawn(strategy: :horizontal )['url'].split( ':' ).first).to eq(preferred)
                        expect(%W{127.0.0.3 127.0.0.2}).to include d1.spawn['url'].split( ':' ).first
                        expect(d2.spawn(strategy: :horizontal )['url'].split( ':' ).first).to eq(preferred)
                        expect(%W{127.0.0.1 127.0.0.2}).to include d3.spawn(strategy: :horizontal )['url'].split( ':' ).first
                        expect(%W{127.0.0.1 127.0.0.3}).to include d3.spawn(strategy: :horizontal )['url'].split( ':' ).first
                        expect(%W{127.0.0.2 127.0.0.3}).to include d1.spawn(strategy: :horizontal )['url'].split( ':' ).first
                    end
                end

                context 'other' do
                    it 'returns :error_unknown_strategy' do
                        expect(agent_spawn( peer: subject.url, daemonize: true ).
                          spawn( strategy: 'blah' )).to eq('error_unknown_strategy')
                    end
                end
            end

            context 'when the load-balance option is set to false' do
                it 'returns an Instance from the requested Agent' do
                    d1 = agent_spawn(
                        address: '127.0.0.1',
                        application: "#{fixtures_path}/mock_app.rb",
                        daemonize: true
                    )

                    d1.spawn( strategy: :direct )

                    d2 = agent_spawn(
                        address:   '127.0.0.2',
                        peer: d1.url,
                        application: "#{fixtures_path}/mock_app.rb",
                        daemonize: true
                    )
                    d2.spawn( strategy: :direct )

                    d3 = agent_spawn(
                        address:   '127.0.0.3',
                        peer: d1.url,
                        application: "#{fixtures_path}/mock_app.rb",
                        daemonize: true
                    )
                    2.times do
                        d3.spawn( strategy: :direct )
                    end

                    expect(d3.spawn( strategy: :direct )['url'].
                        split( ':' ).first).to eq('127.0.0.3')
                end
            end
        end
    end

    describe '#instance' do
        it 'returns proc info by PID' do
            instance = subject.spawn( owner: 'rspec' )
            info = subject.instance( instance['pid'] )
            instance_info_keys.each do |k|
                expect(info[k]).to be_truthy
            end
        end
    end

    describe '#instances' do
        it 'returns proc info by PID for all instances' do
            slots.times { subject.spawn( owner: 'rspec' ) }

            subject.instances.each do |instance|
                instance_info_keys.each do |k|
                    expect(instance[k]).to be_truthy
                end
            end
        end
    end

    describe '#running_instances' do
        it 'returns proc info for running instances' do
            slots.times { subject.spawn }

            expect(subject.running_instances.size).to eq(slots)
        end
    end

    describe '#finished_instances' do
        it 'returns proc info for finished instances' do
            3.times { Cuboid::Processes::Manager.kill subject.spawn['pid'] }

            expect(subject.finished_instances.size).to eq(3)
        end
    end

    describe '#utilization' do
        it 'returns a float signifying the amount of workload' do
            3.times do
                subject.spawn
            end

            expect(subject.utilization).to eq(3 / Float(slots))
        end
    end

    describe '#statistics' do
        it 'returns general statistics' do
            subject.spawn
            instances = subject.instances
            Cuboid::Processes::Manager.kill( instances.first['pid'] )

            stats = subject.statistics

            %w(utilization running_instances finished_instances node
                consumed_pids snapshots).each do |k|
                expect(stats[k]).to be_truthy
            end

            finished = stats['finished_instances']
            expect(finished.size).to eq(1)

            expect(stats['node']).to eq(subject.node.info)
        end

        context 'when there are snapshots' do
            it 'lists them' do
                info = subject.spawn

                instance = Cuboid::RPC::Client::Instance.new(
                    info['url'], info['token']
                )

                instance.run
                instance.suspend!
                sleep 1 while !instance.suspended?
                snapshot_path = instance.snapshot_path
                instance.shutdown

                expect(subject.statistics['snapshots']).to include snapshot_path
            end
        end
    end

    describe '#log' do
        it 'returns the contents of the log file' do
            expect(subject.log).to be_truthy
        end
    end

end
