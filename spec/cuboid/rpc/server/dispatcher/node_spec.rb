require 'spec_helper'
require "#{Cuboid::Options.paths.lib}/rpc/server/dispatcher"

describe Cuboid::RPC::Server::Dispatcher::Node do

    def get_node( port = available_port )
        Cuboid::Options.rpc.server_port = port

        Cuboid::Processes::Manager.spawn( :node )

        c = Cuboid::RPC::Client::Base.new(
            "#{Cuboid::Options.rpc.server_address}:#{port}"
        )
        c = Arachni::RPC::Proxy.new( c, 'node' )

        begin
            c.alive?
        rescue Arachni::RPC::Exceptions::ConnectionError
            sleep 0.1
            retry
        end

        c
    end

    before( :each ) do
        options.paths.executables        = "#{fixtures_path}executables/"
        options.dispatcher.ping_interval = 0.5
    end
    after( :each )  do
        Cuboid::Processes::Manager.killall
    end

    let(:subject) { get_node }
    let(:options) { Cuboid::Options }

    describe '#grid_member?' do
        context 'when the dispatcher is a grid member' do
            it 'should return true' do
                options.dispatcher.neighbour = subject.url

                c = get_node
                sleep 0.5

                expect(c.grid_member?).to be_truthy
            end
        end

        context 'when the dispatcher is not a grid member' do
            it 'should return false' do
                expect(subject.grid_member?).to be_falsey
            end
        end
    end

    context 'when a previously unreachable neighbour comes back to life' do
        it 'gets re-added to the neighbours list' do
            port = available_port
            subject.add_neighbour( '127.0.0.1:' + port.to_s )

            sleep 3
            expect(subject.neighbours).to be_empty

            c = get_node( port )

            sleep 0.5
            expect(subject.neighbours).to eq([c.url])
            expect(c.neighbours).to eq([subject.url])
        end
    end

    context 'when a neighbour becomes unreachable' do
        it 'is removed' do
            c = get_node

            subject.add_neighbour( c.url )
            sleep 0.5

            expect(c.neighbours).to eq([subject.url])
            expect(subject.neighbours).to eq([c.url])

            subject.shutdown rescue break while sleep 0.1
            sleep 0.5

            expect(c.neighbours).to be_empty
        end
    end

    context 'when initialised with a neighbour' do
        it 'adds that neighbour and reach convergence' do
            options.dispatcher.neighbour = subject.url

            c = get_node
            sleep 0.5
            expect(c.neighbours).to eq([subject.url])
            expect(subject.neighbours).to eq([c.url])

            d = get_node
            sleep 0.5
            expect(d.neighbours.sort).to eq([subject.url, c.url].sort)
            expect(c.neighbours.sort).to eq([subject.url, d.url].sort)
            expect(subject.neighbours.sort).to eq([c.url, d.url].sort)

            options.dispatcher.neighbour = d.url
            e = get_node
            sleep 0.5
            expect(e.neighbours.sort).to eq([subject.url, c.url, d.url].sort)
            expect(d.neighbours.sort).to eq([subject.url, c.url, e.url].sort)
            expect(c.neighbours.sort).to eq([subject.url, d.url, e.url].sort)
            expect(subject.neighbours.sort).to eq([c.url, d.url, e.url].sort)
        end
    end

    describe '#unplug' do
        it 'removes itself from the Grid' do
            c = get_node

            subject.add_neighbour( c.url )
            sleep 0.5
            expect(c.neighbours).to eq([subject.url])

            c.unplug

            expect(c.neighbours).to be_empty
            expect(c.grid_member?).to be_falsey
        end
    end

    describe '#add_neighbour' do
        before(:each) do
            subject.add_neighbour( other.url )
            sleep 0.5
        end

        let( :other ) { get_node }

        it 'adds a neighbour' do
            expect(subject.neighbours).to eq([other.url])
            expect(other.neighbours).to eq([subject.url])
        end

        context 'when propagate is set to true' do
            it 'announces the new neighbour to the existing neighbours' do
                n = get_node
                subject.add_neighbour( n.url, true )
                sleep 0.5

                expect(subject.neighbours.sort).to eq([other.url, n.url].sort)
                expect(other.neighbours.sort).to eq([subject.url, n.url].sort)

                c = get_node
                n.add_neighbour( c.url, true )
                sleep 0.5

                expect(subject.neighbours.sort).to eq([other.url, n.url, c.url].sort)
                expect(other.neighbours.sort).to eq([subject.url, n.url, c.url].sort)
                expect(c.neighbours.sort).to eq([subject.url, n.url, other.url].sort)

                d = get_node
                d.add_neighbour( c.url, true )
                sleep 0.5

                expect(subject.neighbours.sort).to eq([d.url, other.url, n.url, c.url].sort)
                expect(other.neighbours.sort).to eq([d.url, subject.url, n.url, c.url].sort)
                expect(c.neighbours.sort).to eq([d.url, subject.url, n.url, other.url].sort)
                expect(d.neighbours.sort).to eq([c.url, subject.url, n.url, other.url].sort)
            end
        end
    end

    describe '#neighbours' do
        it 'returns an array of neighbours' do
            expect(subject.neighbours.is_a?( Array )).to be_truthy
        end
    end

    describe '#neighbours_with_info' do
        it 'returns all neighbours accompanied by their node info' do
            subject.add_neighbour( get_node.url )
            sleep 0.5

            expect(subject.neighbours).to be_any
            expect(subject.neighbours_with_info.size).to eq (subject.neighbours.size)

            keys = subject.info.keys.sort
            subject.neighbours_with_info.each do |i|
                expect(i.keys.sort).to eq(keys)
            end
        end
    end

    describe '#info' do
        it 'returns node info' do
            options.dispatcher.name = 'blah'

            c = get_node
            subject.add_neighbour( c.url )
            sleep 0.5

            info = subject.info

            expect(info['url']).to eq(subject.url)
            expect(info['neighbours']).to eq(subject.neighbours)
            expect(info['unreachable_neighbours']).to be_empty
            expect(info['name']).to eq(options.dispatcher.name)
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
