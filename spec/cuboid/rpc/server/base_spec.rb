require 'spec_helper'
require "#{Cuboid::Options.paths.lib}/rpc/server/base"

describe Cuboid::RPC::Server::Base do
    before( :each ) do
        Raktr.global.run_in_thread
    end

    let(:subject) { Cuboid::RPC::Server::Base.new(
        host: 'localhost', port: port
    ) }
    let(:port) { available_port }

    it 'supports UNIX sockets', if: Raktr.supports_unix_sockets? do
        server = Cuboid::RPC::Server::Base.new(
            socket: "#{Dir.tmpdir}/cuboid-base-#{Cuboid::Utilities.generate_token}"
        )

        server.start

        raised = false
        begin
            Timeout.timeout( 20 ){
                sleep 0.1 while !server.ready?
            }
        rescue Exception => e
            raised = true
        end

        expect(server.ready?).to be_truthy
        expect(raised).to be_falsey
    end

    describe '#ready?' do
        context 'when the server is not ready' do
            it 'returns false' do
                expect(subject.ready?).to be_falsey
            end
        end

        context 'when the server is ready' do
            it 'returns true' do
                subject.start

                raised = false
                begin
                    Timeout.timeout( 20 ){
                        sleep 0.1 while !subject.ready?
                    }
                rescue Exception => e
                    raised = true
                end

                expect(subject.ready?).to be_truthy
                expect(raised).to be_falsey
            end
        end
    end

end
