require 'puma'
require 'puma/minissl'
require 'sinatra/base'
require 'sinatra/contrib'
# Rack 3 gemified Rack::Session out into the rack-session gem; sinatra-contrib
# pulls it in transitively, but the Rack::Session::Pool constant only loads
# when the session-pool file is required directly. Without this the
# `use Rack::Session::Pool` line below NameErrors at boot.
require 'rack/session/pool'

module Cuboid
module Rest

class Server < Sinatra::Base
    lib = Options.paths.lib
    require lib + 'processes'
    require lib + 'rest/server/instance_helpers'

    Dir.glob( "#{File.dirname( __FILE__ )}/server/routes/*.rb" ).each { |f| require f }

    helpers ::Cuboid::Rest::Server::InstanceHelpers

    register Sinatra::Namespace
    Cuboid::Application.application.rest_services.each do |name, service|
        namespace "/instances/:instance/#{name}" do
            register service
        end
    end

    register Routes::Instances
    register Routes::Agent
    register Routes::Grid
    register Routes::Scheduler

    use Rack::Deflater
    use Rack::Session::Pool

    set :environment, :production

    enable :logging

    # sinatra-contrib's default `:json_encoder` is `MultiJson`, and its
    # `resolve_encoder_action` tries `:encode` before `:generate`. Under
    # multi_json 1.20+, `MultiJson.encode` is a deprecated alias to
    # `dump` and emits a warning on every call. Pin the encoder to
    # stdlib `JSON` (which exposes `generate`) to bypass the alias and
    # silence the deprecation without a downstream gem bump.
    set :json_encoder, ::JSON

    before do
        # Rack 3 reads and consumes `rack.input` to build the params hash
        # for known content types (application/x-www-form-urlencoded,
        # multipart/...) BEFORE the route handler runs. After that
        # consumption `request.body.read` returns "" until the IO is
        # rewound. Cuboid's REST routes hand-parse JSON via
        # `JSON.load(request.body.read)`, so without this rewind every
        # PUT/POST that ships a JSON body silently looks empty under
        # Rack 3 — `Options.scheduler.url`, scan options, etc. never get
        # set and downstream routes 404. Idempotent under Rack 2.
        request.body.rewind if request.body.respond_to?(:rewind)

        protected!
        content_type :json
    end

    helpers do
        def max_utilization!
            halt 503,
                 json( error: 'Service unavailable: System is at maximum ' +
                                  'utilization, slot limit reached.' )
        end

        def protected!
            if !settings.respond_to?( :username )
                settings.set :username, nil
            end

            if !settings.respond_to?( :password )
                settings.set :password, nil
            end

            return if !settings.username && !settings.password
            return if authorized?

            headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
            halt 401, "Not authorized\n"
        end

        def authorized?
            @auth ||= Rack::Auth::Basic::Request.new( request.env )
            @auth.provided? && @auth.basic? && @auth.credentials == [
                settings.username.to_s, settings.password.to_s
            ]
        end

        def ensure_instance!
            update_from_scheduler

            id = params[:instance]

            return if exists? id

            halt 404, json( "Scan not found for id: #{h id}." )
        end

        def ensure_agent!
            return if agent
            halt 501, json( 'No Agent has been set.' )
        end

        def ensure_scheduler!
            return if scheduler
            halt 501, json( 'No Scheduler has been set.' )
        end

        def handle_error( cleanup = nil, &block )
            block.call
        rescue => e
            cleanup.call if cleanup

            halt 500,
                 json(
                     error:       e.class,
                     description: e.to_s,
                     backtrace:   e.backtrace
                 )
        end

        def h( text )
            Rack::Utils.escape_html( text )
        end
    end

    class <<self
        include Cuboid::UI::Output

        def reset
            @@instances.clear
            @@agents.clear
        end

        def run!( options )
            set :username, options[:username]
            set :password, options[:password]

            server = Puma::Server.new( self )

            ssl = false
            if (tls = options[:tls]) && tls[:private_key] && tls[:certificate]
                ctx = Puma::MiniSSL::Context.new

                ctx.key  = tls[:private_key]
                ctx.cert = tls[:certificate]

                if tls[:ca]
                    puts 'CA provided, peer verification has been enabled.'

                    ctx.ca          = tls[:ca]
                    ctx.verify_mode = Puma::MiniSSL::VERIFY_PEER |
                        Puma::MiniSSL::VERIFY_FAIL_IF_NO_PEER_CERT
                else
                    puts 'CA missing, peer verification has been disabled.'
                end

                ssl = true
                server.binder.add_ssl_listener( options[:bind], options[:port], ctx )
            else
                ssl = false
                server.add_tcp_listener( options[:bind], options[:port] )
            end

            puts "Listening on http#{'s' if ssl}://#{options[:bind]}:#{options[:port]}"

            begin
                server.run.join
            rescue Interrupt
                server.stop( true )
            end
        end
    end

end

end
end
