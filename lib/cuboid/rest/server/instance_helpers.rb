module Cuboid
module Rest
class Server

module InstanceHelpers

    @@instances   = {}
    @@dispatchers = {}

    def get_instance
        if dispatcher
            options = {
              owner:   self.class.to_s,
              helpers: {
                    owner: {
                        url: env['HTTP_HOST']
                    }
                }
            }

            if (info = dispatcher.dispatch( options ))
                connect_to_instance( info['url'], info['token'] )
            end
        else
            Processes::Instances.spawn( application: Options.paths.application )
        end
    end

    def dispatchers
        @@dispatchers.keys
    end

    def dispatcher
        return if !Options.dispatcher.url
        @dispatcher ||= connect_to_dispatcher( Options.dispatcher.url )
    end

    def unplug_dispatcher( url )
        connect_to_dispatcher( url ).node.unplug

        c = @@dispatchers.delete( url )
        c.close if c
    end

    def connect_to_dispatcher( url )
        @@dispatchers[url] ||= RPC::Client::Dispatcher.new( url )
    end

    def connect_to_instance( url, token )
        RPC::Client::Instance.new( url, token )
    end

    def update_from_scheduler
        return if !scheduler

        scheduler.running.each do |id, info|
            instances[id] ||= connect_to_instance( info['url'], info['token'] )
        end

        (scheduler.failed.keys | scheduler.completed.keys).each do |id|
            session.delete id
            client = instances.delete( id )
            client.close if client
        end
    end

    def scheduler
        return if !Options.scheduler.url
        @scheduler ||= connect_to_scheduler( Options.scheduler.url )
    end

    def connect_to_scheduler( url )
        RPC::Client::Scheduler.new( url )
    end

    def instances
        @@instances
    end

    def instance_for( id, &block )
        cleanup = proc do
            instances.delete( id ).close
            session.delete id
        end

        handle_error cleanup do
            block.call @@instances[id]
        end
    end

    def exists?( id )
        instances.include? id
    end

end

end
end
end
