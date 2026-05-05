require 'spec_helper'
require "#{Cuboid::Options.paths.lib}/mcp/auth"

describe Cuboid::MCP::Auth do
    # Inner app: any time the middleware passes a request through, the
    # inner app records the env it saw and replies 200 OK. Lets us
    # check that env['cuboid.mcp.auth'] is populated AND that
    # short-circuited (401) requests never reach it.
    let(:inner_app) do
        seen = []
        app = ->(env) {
            seen << env
            [200, { 'content-type' => 'text/plain' }, ['ok']]
        }
        # Expose `seen` for assertions.
        app.singleton_class.send(:define_method, :seen_envs) { seen }
        app
    end

    let(:middleware) { described_class.new(inner_app) }

    # Each test installs a fresh anonymous Application subclass so we
    # don't leak validators across examples.
    let(:fake_application) { Class.new(Cuboid::Application) }

    before(:each) do
        @prev_application = Cuboid::Application.application
        Cuboid::Application.application = fake_application
    end

    after(:each) do
        Cuboid::Application.application = @prev_application
    end

    def env(headers = {})
        # Minimum env Rack expects; HTTP_AUTHORIZATION is the only
        # header the middleware reads.
        {
            'REQUEST_METHOD'    => 'POST',
            'PATH_INFO'         => '/mcp',
            'rack.input'        => StringIO.new('{}'),
            'rack.errors'       => StringIO.new
        }.merge(headers)
    end

    context 'when no validator is registered' do
        it 'passes the request through unchanged' do
            status, _, _ = middleware.call(env)
            status.should == 200
            inner_app.seen_envs.size.should == 1
        end

        it 'does not populate cuboid.mcp.auth' do
            middleware.call(env)
            inner_app.seen_envs.first['cuboid.mcp.auth'].should be_nil
        end
    end

    context 'when a validator is registered' do
        before do
            fake_application.mcp_authenticate_with do |token|
                token == 'good-token' ? { user: 'alice' } : nil
            end
        end

        context 'and the Authorization header is missing' do
            it 'responds 401 with invalid_request' do
                status, headers, body = middleware.call(env)

                status.should == 401
                headers['www-authenticate']
                    .should == 'Bearer realm="MCP", error="invalid_request"'

                JSON.parse(body.first)['error']['message'].should == 'invalid_request'
            end

            it 'never reaches the inner app' do
                middleware.call(env)
                inner_app.seen_envs.should be_empty
            end
        end

        context 'and the Authorization header is not a Bearer scheme' do
            it 'responds 401 with invalid_request' do
                status, _, _ = middleware.call(
                    env('HTTP_AUTHORIZATION' => 'Basic dXNlcjpwYXNz')
                )
                status.should == 401
                inner_app.seen_envs.should be_empty
            end
        end

        context 'and the Bearer token is wrong' do
            it 'responds 401 with invalid_token' do
                status, headers, _ = middleware.call(
                    env('HTTP_AUTHORIZATION' => 'Bearer not-the-token')
                )

                status.should == 401
                headers['www-authenticate']
                    .should == 'Bearer realm="MCP", error="invalid_token"'

                inner_app.seen_envs.should be_empty
            end
        end

        context 'and the Bearer token is correct' do
            it 'passes the request through' do
                status, _, _ = middleware.call(
                    env('HTTP_AUTHORIZATION' => 'Bearer good-token')
                )
                status.should == 200
            end

            it "stashes the validator's return value in env['cuboid.mcp.auth']" do
                middleware.call(
                    env('HTTP_AUTHORIZATION' => 'Bearer good-token')
                )

                inner_app.seen_envs.first['cuboid.mcp.auth']
                    .should == { user: 'alice' }
            end

            it 'is case-insensitive on the Bearer keyword' do
                status, _, _ = middleware.call(
                    env('HTTP_AUTHORIZATION' => 'bearer good-token')
                )
                status.should == 200
            end

            it 'tolerates extra whitespace between Bearer and the token' do
                status, _, _ = middleware.call(
                    env('HTTP_AUTHORIZATION' => "Bearer    good-token")
                )
                status.should == 200
            end
        end

        context 'and the validator raises' do
            before do
                fake_application.mcp_authenticate_with do |_token|
                    raise 'database is down'
                end
            end

            it 'responds 401 (not 500) so internals never leak' do
                status, headers, _ = middleware.call(
                    env('HTTP_AUTHORIZATION' => 'Bearer whatever')
                )

                status.should == 401
                headers['www-authenticate']
                    .should == 'Bearer realm="MCP", error="invalid_token"'

                inner_app.seen_envs.should be_empty
            end
        end
    end

    context 'when the validator is replaced after the middleware was instantiated' do
        # Important property: the middleware reads the validator at
        # request time, not at construction time, so applications can
        # swap implementations during a long-running process.
        it 'picks up the new validator on the next request' do
            mw = middleware

            status, _, _ = mw.call(env('HTTP_AUTHORIZATION' => 'Bearer x'))
            status.should == 200   # no validator yet → pass-through

            fake_application.mcp_authenticate_with { |t| t == 'x' }

            status, _, _ = mw.call(env('HTTP_AUTHORIZATION' => 'Bearer x'))
            status.should == 200

            status, _, _ = mw.call(env('HTTP_AUTHORIZATION' => 'Bearer y'))
            status.should == 401
        end
    end
end
