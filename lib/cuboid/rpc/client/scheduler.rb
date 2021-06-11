module Cuboid

require Options.paths.lib + 'rpc/client/base'

module RPC
class Client

# RPC Scheduler client
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Scheduler
    # Not always available, set by the parent.
    attr_accessor :pid

    def initialize( url, options = nil )
        @client = Base.new( url, nil, options )
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

    def close
        @client.close
    end

    private

    # Used to provide the illusion of locality for remote methods
    def method_missing( sym, *args, &block )
        @client.call( "scheduler.#{sym.to_s}", *args, &block )
    end

end

end
end
end
