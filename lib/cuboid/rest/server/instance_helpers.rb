require_relative '../../server/instance_helpers'

module Cuboid
module Rest
class Server

# Sinatra-coupled supplement to `Cuboid::Server::InstanceHelpers` —
# the methods that read `env` or call `handle_error` (a Sinatra helper
# defined on `Rest::Server`). Everything that doesn't need Sinatra
# stays on the shared module above.
module InstanceHelpers

    include ::Cuboid::Server::InstanceHelpers

    # Forward the request host to the shared spawner so the Agent can
    # log who asked for the instance.
    def spawn( owner_url: env['HTTP_HOST'] )
        super
    end

    def instance_for( id, &block )
        cleanup = proc { instances.delete( id ).close }

        handle_error cleanup do
            block.call instances[id]
        end
    end

end

end
end
end
