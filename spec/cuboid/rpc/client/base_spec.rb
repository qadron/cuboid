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
        Raktr.global.run_in_thread if !Raktr.global.running?
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
                        puts "\n[DEBUG] Server started with SSL at: #{server.url}"
                        puts "[DEBUG] Server SSL options: #{server_ssl_options.inspect}"
                        puts "[DEBUG] Client SSL options (after deletion): #{client_ssl_options.inspect}"
                        
                        raised = false
                        exception_class = nil
                        exception_message = nil
                        
                        begin
                            puts "[DEBUG] Creating client with URL: #{server.url}"
                            client = described_class.new( server.url, nil, client_ssl_options )
                            puts "[DEBUG] Client created successfully: #{client.inspect}"
                            
                            puts "[DEBUG] Attempting to call foo.bar..."
                            result = client.call( "foo.bar" )
                            puts "[DEBUG] Call succeeded with result: #{result.inspect}"
                        rescue Toq::Exceptions::ConnectionError => e
                            raised = true
                            exception_class = e.class
                            exception_message = e.message
                            puts "[DEBUG] Caught expected ConnectionError: #{e.message}"
                        rescue => e
                            exception_class = e.class
                            exception_message = e.message
                            puts "[DEBUG] Caught unexpected exception #{e.class}: #{e.message}"
                            puts "[DEBUG] Backtrace: #{e.backtrace.first(5).join("\n")}"
                        end

                        puts "[DEBUG] Exception raised: #{raised}"
                        puts "[DEBUG] Exception class: #{exception_class}"
                        puts "[DEBUG] Exception message: #{exception_message}"
                        
                        expect(raised).to be_truthy, 
                            "Expected Toq::Exceptions::ConnectionError to be raised when connecting to SSL server with invalid SSL options. " \
                            "Instead, #{exception_class ? "got #{exception_class}: #{exception_message}" : "no exception was raised"}"
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
                        rescue Toq::Exceptions::ConnectionError
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
                        rescue Toq::Exceptions::InvalidToken
                            raised = true
                        end

                        expect(raised).to be_truthy
                    end
                end
            end
        end
    end

end
