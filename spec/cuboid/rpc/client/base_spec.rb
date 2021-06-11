require 'spec_helper'
require "#{Cuboid::Options.paths.lib}/rpc/server/base"

class Server
    def initialize( opts, token = nil, &block )
        @server = Cuboid::RPC::Server::Base.new( opts, token )
        @server.add_handler( "foo", self )

        if block_given?
            start
            block.call self
            process_kill_reactor
        end
    end

    def url
        @server.url
    end

    def start
        Arachni::Reactor.global.run_in_thread if !Arachni::Reactor.global.running?
        @server.start
        sleep( 0.1 ) while !@server.ready?
    end

    def bar
        true
    end
end

describe Cuboid::RPC::Client::Base do
    let(:empty_options) do
        {}
    end

    let(:options) do
        {
            host: Cuboid::Options.rpc.server_address,
            port: available_port
        }
    end

    let(:server_ssl_options) do
        options.merge(
            ssl_ca:   support_path + 'pems/cacert.pem',
            ssl_pkey: support_path + 'pems/server/key.pem',
            ssl_cert: support_path + 'pems/server/cert.pem'
        )
    end

    let(:client_ssl_options) do
        {
            ssl_ca:   support_path + 'pems/cacert.pem',
            ssl_pkey: support_path + 'pems/client/key.pem',
            ssl_cert: support_path + 'pems/client/cert.pem'
        }
    end

    describe '.new' do
        context 'without SSL options' do
            it 'connects to a server' do
                Server.new( options ) do |server|
                    client = described_class.new( server.url, nil, options )
                    expect(client.call( "foo.bar" )).to eq(true)
                end
            end
        end

        context 'when trying to connect to an SSL-enabled server' do
            context 'with valid SSL options' do
                it 'connects successfully' do
                    Server.new( server_ssl_options ) do |server|
                        client = described_class.new( server.url, nil, client_ssl_options )
                        expect(client.call( "foo.bar" )).to be_truthy
                    end
                end
            end

            context 'with invalid SSL options' do
                it 'throws an exception' do
                    client_ssl_options.delete :ssl_pkey
                    client_ssl_options.delete :ssl_cert

                    Server.new( server_ssl_options ) do |server|
                        raised = false
                        begin
                            client = described_class.new( server.url, nil, client_ssl_options )
                            client.call( "foo.bar" )
                        rescue Arachni::RPC::Exceptions::ConnectionError
                            raised = true
                        end

                        expect(raised).to be_truthy
                    end
                end
            end

            context 'with no SSL options' do
                it 'throws an exception' do
                    Server.new( server_ssl_options ) do |server|
                        raised = false
                        begin
                            client = described_class.new( server.url, nil, empty_options )
                            client.call( "foo.bar" )
                        rescue Arachni::RPC::Exceptions::ConnectionError
                            raised = true
                        end

                        expect(raised).to be_truthy
                    end
                end
            end
        end

        context 'when a server requires a token' do
            context 'with a valid token' do
                it 'connects successfully' do
                    opts = options.dup
                    opts[:port] = available_port
                    token = 'secret!'

                    Server.new( opts, token ) do |server|
                        client = described_class.new( server.url, token, opts )
                        expect(client.call( "foo.bar" )).to be_truthy
                    end
                end
            end

            context 'with invalid token' do
                it 'throws an exception' do
                    opts = options.dup
                    opts[:port] = available_port
                    token = 'secret!'

                    Server.new( opts, token ) do |server|
                        raised = false
                        begin
                            client = described_class.new( server.url, nil, empty_options )
                            client.call( "foo.bar" )
                        rescue Arachni::RPC::Exceptions::InvalidToken
                            raised = true
                        end

                        expect(raised).to be_truthy
                    end
                end
            end
        end
    end

end
