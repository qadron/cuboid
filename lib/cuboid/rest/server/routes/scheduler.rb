module Cuboid
module Rest
class Server
module Routes

module Scheduler

    def self.registered( app )

        app.get '/scheduler' do
            ensure_scheduler!

            handle_error do
                json scheduler.list
            end
        end

        app.get '/scheduler/url' do
            ensure_scheduler!

            handle_error do
                json Options.scheduler.url
            end
        end

        app.put '/scheduler/url' do
            url = ::JSON.load( request.body.read ) || {}

            handle_error do
                connect_to_scheduler( url ).alive?

                @scheduler = nil
                Options.scheduler.url = url
                json nil
            end
        end

        app.delete '/scheduler/url' do
            ensure_scheduler!

            json @scheduler = Options.scheduler.url = nil
        end

        app.get '/scheduler/running' do
            ensure_scheduler!

            handle_error do
                json scheduler.running
            end
        end

        app.get '/scheduler/completed' do
            ensure_scheduler!

            handle_error do
                json scheduler.completed
            end
        end

        app.get '/scheduler/failed' do
            ensure_scheduler!

            handle_error do
                json scheduler.failed
            end
        end

        app.get '/scheduler/size' do
            ensure_scheduler!

            handle_error do
                json scheduler.size
            end
        end

        app.delete '/scheduler' do
            ensure_scheduler!

            handle_error do
                json scheduler.clear
            end
        end

        app.post '/scheduler' do
            ensure_scheduler!

            handle_error do
                json id: scheduler.push( *[::JSON.load( request.body.read )].flatten )
            end
        end

        app.get '/scheduler/:instance' do |instance|
            ensure_scheduler!

            handle_error do
                instance = scheduler.get( instance )
                if !instance
                    halt 404, json( 'Instance not in Scheduler.' )
                end

                json instance
            end
        end

        app.put '/scheduler/:instance/detach' do |instance|
            ensure_scheduler!

            handle_error do
                info = scheduler.detach( instance )

                if !info
                    halt 404, json( 'Instance not in Scheduler.' )
                end

                instances[instance] ||= connect_to_instance( info['url'], info['token'] )
            end

            json nil
        end

        app.delete '/scheduler/:instance' do |instance|
            ensure_scheduler!

            handle_error do
                if scheduler.remove( instance )
                    json nil
                else
                    halt 404, json( 'Instance not in Scheduler.' )
                end
            end
        end

    end

end

end
end
end
end
