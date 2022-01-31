require_relative '../../../lib/cuboid/processes/manager'
require_relative '../../../lib/cuboid/processes/helpers'
require_relative '../../support/helpers/paths'
require_relative 'web_server_manager'
require 'arachni/rpc'

# @note Needs `ENV['WEB_SERVER_DISPATCHER']` in the format of `host:port`.
#
# Exposes the {WebServerManager} over RPC.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class WebServerAgent

    def initialize( options = {} )
        host, port = ENV['WEB_SERVER_DISPATCHER'].split( ':' )

        manager = WebServerManager.instance
        manager.address = host

        rpc = Cuboid::RPC::Server.new( host: host, port: port.to_i )
        rpc.add_handler( 'server', manager )
        rpc.run
    end

end
