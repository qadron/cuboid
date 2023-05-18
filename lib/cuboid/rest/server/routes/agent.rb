module Cuboid
module Rest
class Server
module Routes

module Agent

    def self.registered( app )

        app.get '/agent/url' do
            ensure_agent!

            json Options.agent.url
        end

        app.put '/agent/url' do
            url = ::JSON.load( request.body.read ) || {}

            handle_error do
                connect_to_agent( url ).alive?

                @agent = nil
                Options.agent.url = url
                json nil
            end
        end

        app.delete '/agent/url' do
            ensure_agent!

            json @agent = Options.agent.url = nil
        end

    end

end

end
end
end
end
