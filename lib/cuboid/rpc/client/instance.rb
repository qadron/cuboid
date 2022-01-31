module Cuboid

require Options.paths.lib + 'rpc/client/base'

module RPC
class Client

# RPC client for remote instances spawned by a remote agent
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Instance
    # Not always available, set by the parent.
    attr_accessor :pid
    attr_reader :options

    require_relative 'instance/service'

    class <<self

        def when_ready( url, token, &block )
            options = Cuboid::Options.rpc.to_client_options.merge(
                client_max_retries:   0,
                connection_pool_size: 1
            )

            client = new( url, token, options )
            Arachni::Reactor.global.delay( 0.1 ) do |task|
                client.alive? do |r|
                    if r.rpc_exception?
                        Arachni::Reactor.global.delay( 0.1, &task )
                        next
                    end

                    client.close

                    block.call
                end
            end
        end

    end

    def initialize( url, token = nil, options = nil )
        @token    = token
        @client   = Base.new( url, token, options )

        @instance = Proxy.new( @client )
        @options  = Arachni::RPC::Proxy.new( @client, 'options' )

        # map Agent handlers
        Cuboid::Application.application.instance_services.keys.each do |name|
            self.class.send( :attr_reader, name.to_sym )

            instance_variable_set(
              "@#{name}".to_sym,
              Arachni::RPC::Proxy.new( @client, name )
            )
        end
    end

    def when_ready( &block )
        self.class.when_ready( url, token, &block )
    end

    def token
        @token
    end

    def client
        @client
    end

    def close
        @client.close
    end

    def url
        @client.url
    end

    def address
        @client.address
    end

    def port
        @client.port
    end

    private

    # Used to provide the illusion of locality for remote methods
    def method_missing( sym, *args, &block )
        @instance.send( sym, *args, &block )
    end

end

end
end
end
