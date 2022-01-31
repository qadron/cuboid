module Cuboid
module Rest
class Server
module Routes

module Grid

    def self.registered( app )

        app.get '/grid' do
            ensure_agent!

            handle_error do
                json [Options.agent.url] + agent.statistics['node']['peers']
            end
        end

        app.get '/grid/:agent' do |url|
            ensure_agent!

            handle_error { json connect_to_agent( url ).statistics }
        end

        app.delete '/grid/:agent' do |url|
            ensure_agent!

            handle_error do
                unplug_agent( url )
            end

            json nil
        end

    end

end

end
end
end
end
