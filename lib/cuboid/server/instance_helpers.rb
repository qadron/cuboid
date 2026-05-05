module Cuboid
module Server

# Shared registry + lookup helpers for the running engine instances
# any front-end (REST, MCP, scheduler-sync) drives. The two
# class-variables (`@@instances`, `@@agents`) are intentionally
# module-level so every includer sees the same map without explicit
# cross-process plumbing.
#
# `spawn` here picks an Agent if one is configured (so grid mode keeps
# working) or falls back to local `Processes::Instances.spawn`.
# Sinatra-only surface — `instance_for`, REST-side scheduler-session
# cleanup, and the env-derived owner URL on `spawn` — lives on
# `Cuboid::Rest::Server::InstanceHelpers`, which mixes this in.
module InstanceHelpers

    @@instances = {}
    @@agents    = {}

    def self.instances
        @@instances
    end

    # Spawn a new engine instance. If an Agent URL is configured the
    # instance is provisioned via the Agent (grid path); otherwise we
    # fork a local one via `Processes::Instances.spawn`.
    #
    # `owner_url` is forwarded to the Agent as `helpers.owner.url` —
    # purely metadata identifying who asked. Sinatra/REST callers pass
    # `env['HTTP_HOST']`; MCP and other non-Rack callers can leave it
    # nil or pass whatever they have. Module-level so callers without
    # an includer context (e.g. `MCP::CoreTools::SpawnInstance`) can
    # use it as `Cuboid::Server::InstanceHelpers.spawn`.
    def self.spawn( owner_url: nil )
        if (a = agent)
            options = {
              owner:   name,
              helpers: { owner: { url: owner_url } }
            }

            if (info = a.spawn( options ))
                connect_to_instance( info['url'], info['token'] )
            end
        else
            ::Cuboid::Processes::Instances.spawn(
                application: ::Cuboid::Options.paths.application,
                daemonize:   true
            )
        end
    end

    def self.agent
        return if !::Cuboid::Options.agent.url
        @@agents[::Cuboid::Options.agent.url] ||=
            ::Cuboid::RPC::Client::Agent.new( ::Cuboid::Options.agent.url )
    end

    def self.connect_to_agent( url )
        @@agents[url] ||= ::Cuboid::RPC::Client::Agent.new( url )
    end

    def self.connect_to_instance( url, token )
        ::Cuboid::RPC::Client::Instance.new( url, token )
    end

    def agents
        @@agents.keys
    end

    def agent
        InstanceHelpers.agent
    end

    def spawn( owner_url: nil )
        InstanceHelpers.spawn( owner_url: owner_url )
    end

    def unplug_agent( url )
        InstanceHelpers.connect_to_agent( url ).node.unplug

        c = @@agents.delete( url )
        c.close if c
    end

    def connect_to_agent( url )
        InstanceHelpers.connect_to_agent( url )
    end

    def connect_to_instance( url, token )
        InstanceHelpers.connect_to_instance( url, token )
    end

    # Pulls scheduler-tracked running instances into the local map and
    # closes/removes any that the scheduler reports failed or completed.
    # Sinatra-side session cleanup for the same IDs is the responsibility
    # of `Cuboid::Rest::Server::InstanceHelpers#update_from_scheduler`,
    # which calls super then prunes its session.
    def update_from_scheduler
        return if !scheduler

        scheduler.running.each do |id, info|
            instances[id] ||= connect_to_instance( info['url'], info['token'] )
        end

        (scheduler.failed.keys | scheduler.completed.keys).each do |id|
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
        InstanceHelpers.instances
    end

    def exists?( id )
        instances.include? id
    end

end

end
end
