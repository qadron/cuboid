require 'toq'

# @note Needs `ENV['WEB_SERVER_DISPATCHER']` in the format of `host:port`.
#
# {WebServerManager}-API-compatible client for the {WebServerAgent}.
#
# Delegates test webserver creation to the machine running {WebServerAgent},
# for hosts that lack support for fast servers (like Windows, which can't run
# Thin, Puma etc.).
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class WebServerClient < Toq::Proxy
    include Singleton

    def initialize( options = {} )
        @host, port = ENV['WEB_SERVER_DISPATCHER'].split( ':' )

        Raktr.global.run_in_thread if !Raktr.global.running?

        client = Toq::Client.new( host: @host, port: port )
        super client, 'server'
    end

    def protocol_for( name )
        name.to_s.include?( 'https' ) ? 'https' : 'http'
    end

    def address_for( name )
        @host
    end

    def up?( name )
        Typhoeus.get(
            url_for( name, false ),
            ssl_verifypeer: false,
            ssl_verifyhost: 0,
            forbid_reuse:   true
        ).code != 0
    end

end
