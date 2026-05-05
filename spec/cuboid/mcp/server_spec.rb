require 'spec_helper'
require "#{Cuboid::Options.paths.lib}/mcp/server"

describe Cuboid::MCP::Server do
    include Rack::Test::Methods

    # Each test gets a fresh anonymous Application subclass so tool /
    # validator registrations don't leak between examples.
    let(:fake_application) { Class.new(Cuboid::Application) }

    # The Server reads from `Cuboid::Application.application` at boot
    # time, so we install the fixture before any rack_app call.
    before(:each) do
        @prev_application = Cuboid::Application.application
        Cuboid::Application.application = fake_application
    end

    after(:each) do
        Cuboid::Application.application = @prev_application
    end

    # Rack::Test's `app` hook — built per-test from current options/state.
    # Default to `stateless: true` so tests can hit individual JSON-RPC
    # methods without an explicit `initialize` handshake first.
    def app
        described_class.rack_app({ stateless: true }.merge(@app_options || {}))
    end

    # Build a JSON-RPC request body the way an MCP client would.
    def jsonrpc(method, params = {}, id: 1)
        {
            jsonrpc: '2.0',
            id:      id,
            method:  method,
            params:  params
        }.to_json
    end

    def post_jsonrpc(method, params = {}, headers: {})
        post '/mcp',
             jsonrpc(method, params),
             {
                'CONTENT_TYPE' => 'application/json',
                'HTTP_ACCEPT'  => 'application/json, text/event-stream'
             }.merge(headers)
    end

    INITIALIZE_PARAMS = {
        protocolVersion: '2025-06-18',
        capabilities:    {},
        clientInfo:      { name: 'spec', version: '0' }
    }.freeze

    context 'with no tools registered' do
        it 'serves a valid initialize handshake' do
            post_jsonrpc 'initialize', INITIALIZE_PARAMS

            last_response.status.should == 200
            body = JSON.parse(last_response.body)
            body['jsonrpc'].should == '2.0'
            body['result']['protocolVersion'].should == '2025-06-18'
            body['result']['serverInfo']['name'].should  be_a(String)
            body['result']['serverInfo']['version'].should be_a(String)
        end

        it 'reports an empty tools list via tools/list' do
            post_jsonrpc 'tools/list'

            last_response.status.should == 200
            body = JSON.parse(last_response.body)
            body['result']['tools'].should == []
        end
    end

    context 'with a tool registered on the application' do
        let(:tool_class) do
            klass = Class.new(MCP::Tool)
            klass.instance_eval do
                tool_name 'echo'
                description 'Returns the input verbatim.'
                input_schema(
                    properties: { message: { type: 'string' } },
                    required:   ['message']
                )

                def self.call(message:, server_context: nil)
                    MCP::Tool::Response.new(
                        [{ type: 'text', text: message }]
                    )
                end
            end
            klass
        end

        before do
            fake_application.mcp_tool_for(tool_class)
        end

        it 'lists the tool via tools/list' do
            post_jsonrpc 'tools/list'

            tools = JSON.parse(last_response.body)['result']['tools']
            tools.size.should == 1
            tools.first['name'].should == 'echo'
        end

        it 'invokes the tool via tools/call' do
            post_jsonrpc 'tools/call',
                         { name: 'echo', arguments: { message: 'hi from spec' } }

            body = JSON.parse(last_response.body)
            body['result']['content'].first['text'].should == 'hi from spec'
        end
    end

    context 'when an auth validator is registered' do
        before do
            fake_application.mcp_authenticate_with do |token|
                token == 'good' ? :ok : nil
            end
        end

        it '401s a request with no Authorization header' do
            post_jsonrpc 'initialize', INITIALIZE_PARAMS
            last_response.status.should == 401
        end

        it 'allows requests with a valid bearer token' do
            post_jsonrpc 'initialize', INITIALIZE_PARAMS,
                         headers: { 'HTTP_AUTHORIZATION' => 'Bearer good' }

            last_response.status.should == 200
        end
    end

    context 'with custom mount path' do
        before { @app_options = { path: '/mcp/v1' } }

        it 'serves the transport at the custom path' do
            post '/mcp/v1',
                 jsonrpc('initialize', INITIALIZE_PARAMS),
                 'CONTENT_TYPE' => 'application/json',
                 'HTTP_ACCEPT'  => 'application/json, text/event-stream'

            last_response.status.should == 200
        end

        it 'returns 404 at the default /mcp path' do
            post '/mcp',
                 jsonrpc('initialize', INITIALIZE_PARAMS),
                 'CONTENT_TYPE' => 'application/json',
                 'HTTP_ACCEPT'  => 'application/json, text/event-stream'

            last_response.status.should == 404
        end
    end

    context 'with custom name and version' do
        before do
            @app_options = { name: 'spectre-mcp', version: '7.7.7' }
        end

        it 'advertises them in serverInfo' do
            post_jsonrpc 'initialize', INITIALIZE_PARAMS

            info = JSON.parse(last_response.body)['result']['serverInfo']
            info['name'].should    == 'spectre-mcp'
            info['version'].should == '7.7.7'
        end
    end
end
