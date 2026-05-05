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
        # Reset the shared instances map so per-example fixtures don't
        # bleed into the next example.
        Cuboid::Server::InstanceHelpers.instances.clear
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
        Cuboid::Server::InstanceHelpers.instances[id] = instance_obj
        instance_obj
    end

    context 'when the path is unrecognised' do
        before do
            fake_application.mcp_service_for(:my_service, build_handler_with_tools)
            stub_instance('inst-1')
        end

        it '404s an unrelated path' do
            post_jsonrpc '/random/path', 'initialize', INITIALIZE_PARAMS
            last_response.status.should == 404
        end
    end

    context 'core tools at /mcp (framework-level)' do
        # Stub double for kill_instance: needs `.shutdown` and `.close`.
        let(:killable) do
            obj = Object.new
            obj.define_singleton_method(:shutdown) { nil }
            obj.define_singleton_method(:close)    { nil }
            obj
        end

        it 'serves an initialize handshake' do
            post_jsonrpc '/mcp', 'initialize', INITIALIZE_PARAMS

            last_response.status.should == 200
            JSON.parse(last_response.body)['result']['protocolVersion']
                .should == '2025-06-18'
        end

        it 'lists the framework tools (list/spawn/kill instance)' do
            post_jsonrpc '/mcp', 'tools/list'

            names = JSON.parse(last_response.body)['result']['tools'].map { |t| t['name'] }
            names.sort.should == %w[kill_instance list_instances spawn_instance]
        end

        it 'list_instances returns currently-registered ids' do
            stub_instance('inst-a')
            stub_instance('inst-b')

            post_jsonrpc '/mcp', 'tools/call', { name: 'list_instances', arguments: {} }

            structured = JSON.parse(last_response.body)['result']['structuredContent']
            structured['instances'].keys.sort.should == %w[inst-a inst-b]
        end

        it 'kill_instance removes the instance from the shared map' do
            stub_instance('inst-x', killable)

            post_jsonrpc '/mcp', 'tools/call',
                         { name: 'kill_instance', arguments: { instance_id: 'inst-x' } }

            structured = JSON.parse(last_response.body)['result']['structuredContent']
            structured['killed'].should == 'inst-x'
            Cuboid::Server::InstanceHelpers.instances.key?('inst-x').should == false
        end

        it 'kill_instance returns an error response when the id is unknown' do
            post_jsonrpc '/mcp', 'tools/call',
                         { name: 'kill_instance', arguments: { instance_id: 'nope' } }

            body    = JSON.parse(last_response.body)
            content = body['result']['content'].first
            body['result']['isError'].should == true
            content['text'].should include('unknown instance')
        end
    end

    context 'with a service registered' do
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
            fake_application.mcp_service_for(:my_service, handler)
            stub_instance('inst-1')
        end

        it 'lists the wrapped tool under its <service>_<tool> name with instance_id required' do
            post_jsonrpc '/mcp', 'tools/list'

            tools = JSON.parse(last_response.body)['result']['tools']
            wrapped = tools.find { |t| t['name'] == 'my_service_echo' }
            wrapped.should_not be_nil
            wrapped['inputSchema']['required'].should include('instance_id')
            wrapped['inputSchema']['properties'].keys.map(&:to_s)
                .should include('instance_id', 'message')
        end

        it 'resolves the instance_id arg into server_context for the wrapped tool' do
            post_jsonrpc '/mcp', 'tools/call',
                         { name: 'my_service_echo',
                           arguments: { instance_id: 'inst-1', message: 'hi' } }

            content = JSON.parse(last_response.body)['result']['content']
            content.first['text'].should == 'inst-1: hi'
        end

        it 'returns an MCP tool error (not a routing 404) when instance_id is unknown' do
            post_jsonrpc '/mcp', 'tools/call',
                         { name: 'my_service_echo',
                           arguments: { instance_id: 'missing', message: 'hi' } }

            body = JSON.parse(last_response.body)
            body['result']['isError'].should == true
            body['result']['content'].first['text'].should include('unknown instance')
        end

        it 'isolates state across instance_ids passed as arguments' do
            stub_instance('inst-2')

            post_jsonrpc '/mcp', 'tools/call',
                         { name: 'my_service_echo',
                           arguments: { instance_id: 'inst-1', message: 'hi' } }
            JSON.parse(last_response.body)['result']['content']
                .first['text'].should == 'inst-1: hi'

            post_jsonrpc '/mcp', 'tools/call',
                         { name: 'my_service_echo',
                           arguments: { instance_id: 'inst-2', message: 'hi' } }
            JSON.parse(last_response.body)['result']['content']
                .first['text'].should == 'inst-2: hi'
        end
    end

    context 'when an auth validator is registered' do
        before do
            fake_application.mcp_service_for(:my_service, build_handler_with_tools)
            stub_instance('inst-1')
            fake_application.mcp_authenticate_with do |token|
                token == 'good' ? :ok : nil
            end
        end

        it '401s a request with no Authorization header' do
            post_jsonrpc '/mcp', 'initialize', INITIALIZE_PARAMS
            last_response.status.should == 401
        end

        it 'allows requests with a valid bearer token' do
            post_jsonrpc '/mcp', 'initialize', INITIALIZE_PARAMS,
                         headers: { 'HTTP_AUTHORIZATION' => 'Bearer good' }
            last_response.status.should == 200
        end
    end

    context 'with custom name / version' do
        before do
            fake_application.mcp_service_for(:my_service, build_handler_with_tools)
            stub_instance('inst-1')
            @app_options = { name: 'spectre-mcp', version: '7.7.7' }
        end

        it 'advertises them in serverInfo' do
            post_jsonrpc '/mcp', 'initialize', INITIALIZE_PARAMS

            info = JSON.parse(last_response.body)['result']['serverInfo']
            info['name'].should    == 'spectre-mcp'
            info['version'].should == '7.7.7'
        end
    end

    context 'when the application class lives under a branded top-level namespace' do
        # Synthesize a real-looking namespace mirroring SCNR/RKN: a
        # `shortname` method (the brand the user wants advertised) and
        # a `version` method (preferred over the VERSION constant when
        # both are present). The dispatcher should pick the branded
        # methods over the raw module name.
        before do
            stub_const('SpectreFake', Module.new)
            SpectreFake.define_singleton_method(:shortname) { :spectre }
            SpectreFake.define_singleton_method(:version)   { '9.9.9'   }
            SpectreFake.const_set(
                :Application,
                Class.new(Cuboid::Application) { def self.name; 'SpectreFake::Application'; end }
            )

            Cuboid::Application.application = SpectreFake::Application
            SpectreFake::Application.mcp_service_for(:my_service, build_handler_with_tools)
            stub_instance('inst-1')
        end

        it 'advertises the brand shortname + version at /mcp' do
            post_jsonrpc '/mcp', 'initialize', INITIALIZE_PARAMS

            info = JSON.parse(last_response.body)['result']['serverInfo']
            info['name'].should    == 'spectre'
            info['version'].should == '9.9.9'
        end

    end

    context 'when the namespace exposes only a VERSION constant (no branded methods)' do
        before do
            stub_const('PlainFake', Module.new)
            PlainFake.const_set(:VERSION, '2.0.0')
            PlainFake.const_set(
                :Application,
                Class.new(Cuboid::Application) { def self.name; 'PlainFake::Application'; end }
            )

            Cuboid::Application.application = PlainFake::Application
            PlainFake::Application.mcp_service_for(:my_service, build_handler_with_tools)
            stub_instance('inst-1')
        end

        it 'falls back to the namespace name + VERSION' do
            post_jsonrpc '/mcp', 'initialize', INITIALIZE_PARAMS

            info = JSON.parse(last_response.body)['result']['serverInfo']
            info['name'].should    == 'PlainFake'
            info['version'].should == '2.0.0'
        end
    end
end
