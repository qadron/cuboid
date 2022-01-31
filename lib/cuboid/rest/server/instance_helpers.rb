module Cuboid
module Rest
class Server

module InstanceHelpers

    @@instances   = {}
    @@agents = {}

    def get_instance
        if agent
            options = {
              owner:   self.class.to_s,
              helpers: {
                    owner: {
                        url: env['HTTP_HOST']
                    }
                }
            }

            if (info = agent.spawn( options ))
                connect_to_instance( info['url'], info['token'] )
            end
        else
            Processes::Instances.spawn( application: Options.paths.application )
        end
    end

    def agents
        @@agents.keys
    end

    def agent
        return if !Options.agent.url
        @agent ||= connect_to_agent( Options.agent.url )
    end

    def unplug_agent( url )
        connect_to_agent( url ).node.unplug

        c = @@agents.delete( url )
        c.close if c
    end

    def connect_to_agent( url )
        @@agents[url] ||= RPC::Client::Agent.new( url )
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
