module Cuboid
module Rest
class Server
module Routes

module Dispatcher

    def self.registered( app )

        app.get '/dispatcher/url' do
            ensure_dispatcher!

            json Options.dispatcher.url
        end

        app.put '/dispatcher/url' do
            url = ::JSON.load( request.body.read ) || {}

            handle_error do
                connect_to_dispatcher( url ).alive?

                @dispatcher = nil
                Options.dispatcher.url = url
                json nil
            end
        end

        app.delete '/dispatcher/url' do
            ensure_dispatcher!

            json @dispatcher = Options.dispatcher.url = nil
        end

    end

end

end
end
end
end
