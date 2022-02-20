require 'spec_helper'
require "#{Cuboid::Options.paths.lib}/rpc/server/agent"

describe Cuboid::RPC::Server::Agent::Node do

    def get_node( port = available_port )
        Cuboid::Options.rpc.server_port = port

        Cuboid::Processes::Manager.spawn( :node )

        c = Cuboid::RPC::Client::Base.new(
            "#{Cuboid::Options.rpc.server_address}:#{port}"
        )
        c = Toq::Proxy.new( c, 'node' )

        begin
            c.alive?
        rescue Toq::Exceptions::ConnectionError
            sleep 0.1
            retry
        end

        c
    end

    before( :each ) do
        options.paths.executables        = "#{fixtures_path}executables/"
        options.agent.ping_interval = 0.5
    end
    after( :each )  do
        Cuboid::Processes::Manager.killall
    end

    let(:subject) { get_node }
    let(:options) { Cuboid::Options }

    describe '#grid_member?' do
        context 'when the agent is a grid member' do
            it 'should return true' do
                options.agent.peer = subject.url

                c = get_node
                sleep 0.5

                expect(c.grid_member?).to be_truthy
            end
        end

        context 'when the agent is not a grid member' do
            it 'should return false' do
                expect(subject.grid_member?).to be_falsey
            end
        end
    end

    context 'when a previously unreachable peer comes back to life' do
        it 'gets re-added to the peers list' do
            port = available_port
            subject.add_peer( '127.0.0.1:' + port.to_s )

            sleep 3
            expect(subject.peers).to be_empty

            c = get_node( port )

            sleep 0.5
            expect(subject.peers).to eq([c.url])
            expect(c.peers).to eq([subject.url])
        end
    end

    context 'when a peer becomes unreachable' do
        it 'is removed' do
            c = get_node

            subject.add_peer( c.url )
            sleep 0.5

            expect(c.peers).to eq([subject.url])
            expect(subject.peers).to eq([c.url])

            subject.shutdown rescue break while sleep 0.1
            sleep 0.5

            expect(c.peers).to be_empty
        end
    end

    context 'when initialised with a peer' do
        it 'adds that peer and reach convergence' do
            options.agent.peer = subject.url

            c = get_node
            sleep 0.5
            expect(c.peers).to eq([subject.url])
            expect(subject.peers).to eq([c.url])

            d = get_node
            sleep 0.5
            expect(d.peers.sort).to eq([subject.url, c.url].sort)
            expect(c.peers.sort).to eq([subject.url, d.url].sort)
            expect(subject.peers.sort).to eq([c.url, d.url].sort)

            options.agent.peer = d.url
            e = get_node
            sleep 0.5
            expect(e.peers.sort).to eq([subject.url, c.url, d.url].sort)
            expect(d.peers.sort).to eq([subject.url, c.url, e.url].sort)
            expect(c.peers.sort).to eq([subject.url, d.url, e.url].sort)
            expect(subject.peers.sort).to eq([c.url, d.url, e.url].sort)
        end
    end

    describe '#unplug' do
        it 'removes itself from the Grid' do
            c = get_node

            subject.add_peer( c.url )
            sleep 0.5
            expect(c.peers).to eq([subject.url])

            c.unplug

            expect(c.peers).to be_empty
            expect(c.grid_member?).to be_falsey
        end
    end

    describe '#add_peer' do
        before(:each) do
            subject.add_peer( other.url )
            sleep 0.5
        end

        let( :other ) { get_node }

        it 'adds a peer' do
            expect(subject.peers).to eq([other.url])
            expect(other.peers).to eq([subject.url])
        end

        context 'when propagate is set to true' do
            it 'announces the new peer to the existing peers' do
                n = get_node
                subject.add_peer( n.url, true )
                sleep 0.5

                expect(subject.peers.sort).to eq([other.url, n.url].sort)
                expect(other.peers.sort).to eq([subject.url, n.url].sort)

                c = get_node
                n.add_peer( c.url, true )
                sleep 0.5

                expect(subject.peers.sort).to eq([other.url, n.url, c.url].sort)
                expect(other.peers.sort).to eq([subject.url, n.url, c.url].sort)
                expect(c.peers.sort).to eq([subject.url, n.url, other.url].sort)

                d = get_node
                d.add_peer( c.url, true )
                sleep 0.5

                expect(subject.peers.sort).to eq([d.url, other.url, n.url, c.url].sort)
                expect(other.peers.sort).to eq([d.url, subject.url, n.url, c.url].sort)
                expect(c.peers.sort).to eq([d.url, subject.url, n.url, other.url].sort)
                expect(d.peers.sort).to eq([c.url, subject.url, n.url, other.url].sort)
            end
        end
    end

    describe '#peers' do
        it 'returns an array of peers' do
            expect(subject.peers.is_a?( Array )).to be_truthy
        end
    end

    describe '#peers_with_info' do
        it 'returns all peers accompanied by their node info' do
            subject.add_peer( get_node.url )
            sleep 0.5

            expect(subject.peers).to be_any
            expect(subject.peers_with_info.size).to eq (subject.peers.size)

            keys = subject.info.keys.sort
            subject.peers_with_info.each do |i|
                expect(i.keys.sort).to eq(keys)
            end
        end
    end

    describe '#info' do
        it 'returns node info' do
            options.agent.name = 'blah'

            c = get_node
            subject.add_peer( c.url )
            sleep 0.5

            info = subject.info

            expect(info['url']).to eq(subject.url)
            expect(info['peers']).to eq(subject.peers)
            expect(info['unreachable_peers']).to be_empty
            expect(info['name']).to eq(options.agent.name)
        end

        context 'when OptionGroups::RPC#server_external_address has been set' do
            it 'advertises that address' do
                options.rpc.server_external_address = '9.9.9.9'

                expect(subject.info['url']).to start_with options.rpc.server_external_address
            end
        end
    end

    describe '#alive?' do
        it 'returns true' do
            expect(subject.alive?).to be_truthy
        end
    end
end
