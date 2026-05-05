require 'spec_helper'
require "#{Cuboid::Options.paths.lib}/mcp/server"

describe Cuboid::MCP::Server do
    include Rack::Test::Methods

    # Each test gets a fresh anonymous Application subclass so service /
    # validator registrations don't leak between examples.
    let(:fake_application) { Class.new(Cuboid::Application) }

    before(:each) do
        @prev_application = Cuboid::Application.application
        Cuboid::Application.application = fake_application
    end

    after(:each) do
        Cuboid::Application.application = @prev_application
        # Reset the shared @@instances class-variable on InstanceHelpers
        # so per-example fixtures don't bleed into the next example.
        Cuboid::Rest::Server::InstanceHelpers.class_variable_set(
            :@@instances, {}
        )
    end

    # Rack::Test's `app` hook — built per-test from current options/state.
    # Default to `stateless: true` so tests can hit individual JSON-RPC
    # methods without an explicit `initialize` handshake first.
    def app
        described_class.rack_app({ stateless: true }.merge(@app_options || {}))
    end

    def jsonrpc(method, params = {}, id: 1)
        {
            jsonrpc: '2.0',
            id:      id,
            method:  method,
            params:  params
        }.to_json
    end

    def post_jsonrpc(path, method, params = {}, headers: {})
        post path,
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

    # Stub for an MCP-tool handler module/class — what an application
    # gem supplies via `mcp_service_for`.
    def build_handler_with_tools(*tools)
        h = Module.new
        h.define_singleton_method(:tools) { tools }
        h
    end

    # Plant an entry in the shared instance map so the dispatcher can
    # resolve `:instance` to something. The value is whatever an RPC
    # client would normally be — for tests we just use a plain
    # double / OpenStruct that the tools may interact with.
    def stub_instance(id, instance_obj = Object.new)
        Cuboid::Rest::Server::InstanceHelpers
            .class_variable_get(:@@instances)[id] = instance_obj
        instance_obj
    end

    context 'when the path does not match /instances/:instance/<service>' do
        before do
            fake_application.mcp_service_for(:scan, build_handler_with_tools)
            stub_instance('inst-1')
        end

        it '404s a top-level POST' do
            post_jsonrpc '/mcp', 'initialize', INITIALIZE_PARAMS
            last_response.status.should == 404
        end

        it '404s an unrelated path' do
            post_jsonrpc '/random/path', 'initialize', INITIALIZE_PARAMS
            last_response.status.should == 404
        end
    end

    context 'when the service is not registered' do
        before { stub_instance('inst-1') }

        it '404s with an explanatory error body' do
            post_jsonrpc '/instances/inst-1/scan', 'initialize', INITIALIZE_PARAMS

            last_response.status.should == 404
            JSON.parse(last_response.body)['error']['message']
                .should include('unknown MCP service')
        end
    end

    context 'when the instance is not in the local map' do
        before do
            fake_application.mcp_service_for(:scan, build_handler_with_tools)
        end

        it '404s with an explanatory error body' do
            post_jsonrpc '/instances/missing/scan', 'initialize', INITIALIZE_PARAMS

            last_response.status.should == 404
            JSON.parse(last_response.body)['error']['message']
                .should include('unknown instance')
        end
    end

    context 'with a service registered and a known instance' do
        let(:tool_class) do
            klass = Class.new(MCP::Tool)
            klass.instance_eval do
                tool_name 'echo'
                description 'Returns "<instance_id>: <message>".'
                input_schema(
                    properties: { message: { type: 'string' } },
                    required:   ['message']
                )

                def self.call(message:, server_context:)
                    text = "#{server_context[:instance_id]}: #{message}"
                    MCP::Tool::Response.new([{ type: 'text', text: text }])
                end
            end
            klass
        end

        let(:handler) { build_handler_with_tools(tool_class) }

        before do
            fake_application.mcp_service_for(:scan, handler)
            stub_instance('inst-1')
        end

        it 'serves an initialize handshake at /instances/:instance/<service>' do
            post_jsonrpc '/instances/inst-1/scan', 'initialize', INITIALIZE_PARAMS

            last_response.status.should == 200
            body = JSON.parse(last_response.body)
            body['result']['protocolVersion'].should == '2025-06-18'
        end

        it 'lists the registered tools via tools/list' do
            post_jsonrpc '/instances/inst-1/scan', 'tools/list'

            tools = JSON.parse(last_response.body)['result']['tools']
            tools.size.should == 1
            tools.first['name'].should == 'echo'
        end

        it 'invokes the tool with the resolved instance in server_context' do
            post_jsonrpc '/instances/inst-1/scan', 'tools/call',
                         { name: 'echo', arguments: { message: 'hi' } }

            content = JSON.parse(last_response.body)['result']['content']
            # Tool sees the resolved instance_id from server_context —
            # proving the dispatcher routed correctly.
            content.first['text'].should == 'inst-1: hi'
        end

        it 'isolates state across distinct (instance, service) pairs' do
            stub_instance('inst-2')

            post_jsonrpc '/instances/inst-1/scan', 'tools/call',
                         { name: 'echo', arguments: { message: 'hi' } }
            JSON.parse(last_response.body)['result']['content']
                .first['text'].should == 'inst-1: hi'

            post_jsonrpc '/instances/inst-2/scan', 'tools/call',
                         { name: 'echo', arguments: { message: 'hi' } }
            JSON.parse(last_response.body)['result']['content']
                .first['text'].should == 'inst-2: hi'
        end
    end

    context 'when an auth validator is registered' do
        before do
            fake_application.mcp_service_for(:scan, build_handler_with_tools)
            stub_instance('inst-1')
            fake_application.mcp_authenticate_with do |token|
                token == 'good' ? :ok : nil
            end
        end

        it '401s a request with no Authorization header' do
            post_jsonrpc '/instances/inst-1/scan', 'initialize', INITIALIZE_PARAMS
            last_response.status.should == 401
        end

        it 'allows requests with a valid bearer token' do
            post_jsonrpc '/instances/inst-1/scan', 'initialize', INITIALIZE_PARAMS,
                         headers: { 'HTTP_AUTHORIZATION' => 'Bearer good' }
            last_response.status.should == 200
        end
    end

    context 'with custom name / version' do
        before do
            fake_application.mcp_service_for(:scan, build_handler_with_tools)
            stub_instance('inst-1')
            @app_options = { name: 'spectre-mcp', version: '7.7.7' }
        end

        it 'advertises them in serverInfo' do
            post_jsonrpc '/instances/inst-1/scan', 'initialize', INITIALIZE_PARAMS

            info = JSON.parse(last_response.body)['result']['serverInfo']
            info['name'].should    == 'spectre-mcp'
            info['version'].should == '7.7.7'
        end
    end
end
