require 'spec_helper'
require "#{Cuboid::Options.paths.lib}/rpc/server/dispatcher"

describe Cuboid::RPC::Server::Dispatcher::Service do
    before( :each ) do
        Cuboid::Options.paths.services   = "#{fixtures_path}services/"
        Cuboid::Options.system.max_slots = 10
    end
    let(:instance_count) { 3 }
    let(:dispatcher) { dispatcher_spawn application: "#{fixtures_path}/mock_app.rb" }
    let(:subject) { dispatcher.test_service }

    describe '#dispatcher' do
        it 'provides access to the parent Dispatcher' do
            expect(subject.test_dispatcher).to be_truthy
        end
    end

    describe '#opts' do
        it 'provides access to the Dispatcher\'s options' do
            expect(subject.test_opts).to be_truthy
        end
    end

    describe '#node' do
        it 'provides access to the Dispatcher\'s node' do
            expect(subject.test_node).to be_truthy
        end
    end

    describe '#instances' do
        before(:each) do
            instance_count.times { dispatcher.dispatch }
        end

        it 'provides access to the running instances' do
            expect(subject.instances.map{ |i| i['pid'] }).to eq(subject.instances.map{ |j| j['pid'] })
        end
    end

    describe '#map_instances' do
        before(:each) do
            instance_count.times { dispatcher.dispatch }
        end

        it 'asynchronously maps all running instances' do
            expect(subject.test_map_instances).to eq(
                Hash[subject.instances.map { |j| [j['url'], j['token']] }]
            )
        end
    end

    describe '#each_instance' do
        before(:each) do
            instance_count.times { dispatcher.dispatch }
        end

        it 'asynchronously iterates over all running instances' do
            subject.test_each_instance
            auths = subject.instances.map do |j|
                Cuboid::RPC::Client::Instance.new(
                    j['url'], j['token']
                ).options.authorized_by
            end

            expect(auths.size).to eq(instance_count)
            auths.sort!

            1.upto( instance_count ).each do |i|
                expect(auths[i-1]).to eq "test_#{i}@test.com"
            end
        end
    end

    describe '#defer' do
        it 'defers execution of the given block' do
            args = [1, 'stuff']
            expect(subject.test_defer( *args )).to eq(args)
        end
    end

    describe '#run_asap' do
        it 'runs the given block as soon as possible' do
            args = [1, 'stuff']
            expect(subject.test_run_asap( *args )).to eq(args)
        end
    end

    describe '#iterator_for' do
        it 'provides an asynchronous iterator' do
            expect(subject.test_iterator_for).to be_truthy
        end
    end

    describe '#connect_to_dispatcher' do
        it 'connects to the a dispatcher by url' do
            expect(subject.test_connect_to_dispatcher( dispatcher.url )).to be_truthy
        end
    end

    describe '#connect_to_instance' do
        it 'connects to an instance' do
            dispatcher.dispatch
            instance = subject.instances.first

            expect(subject.test_connect_to_instance( instance )).to be_falsey
            expect(subject.test_connect_to_instance( instance['url'], instance['token'] )).to be_falsey
            expect(subject.test_connect_to_instance( url: instance['url'], token: instance['token'] )).to be_falsey
        end
    end

end
