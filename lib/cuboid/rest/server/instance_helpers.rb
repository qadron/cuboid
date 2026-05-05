require_relative '../../server/instance_helpers'

module Cuboid
module Rest
class Server

# Sinatra-coupled supplement to `Cuboid::Server::InstanceHelpers` —
# the methods that read `env`, call `handle_error` (a Sinatra helper
# defined on `Rest::Server`), or prune `session` entries belonging to
# scheduler-removed instances. Everything that doesn't need Sinatra
# stays on the shared module above.
module InstanceHelpers

    include ::Cuboid::Server::InstanceHelpers

    # Forward the request host to the shared spawner so the Agent can
    # log who asked for the instance.
    def spawn( owner_url: env['HTTP_HOST'] )
        super
    end

    # Adds Sinatra-session cleanup for IDs the scheduler has dropped.
    # The shared `update_from_scheduler` already removes them from the
    # instance map; this override prunes the matching session keys so a
    # second request from the same browser doesn't try to reach a dead
    # instance.
    def update_from_scheduler
        return if !scheduler

        pruned = scheduler.failed.keys | scheduler.completed.keys
        super
        pruned.each { |id| session.delete id }
    end

    def instance_for( id, &block )
        cleanup = proc do
            instances.delete( id ).close
            session.delete id
        end

        handle_error cleanup do
            block.call instances[id]
        end
    end

end

end
end
end
