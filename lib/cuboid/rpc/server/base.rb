require 'ostruct'
require 'toq'
require_relative '../serializer'

module Cuboid
module RPC
class Server

# RPC server class
#
# @private
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Base < Toq::Server

    # @param    [Hash]   options
    # @option options [Integer]  :host
    # @option options [Integer]  :port
    # @option options [Integer]  :socket
    # @option options [Integer]  :ssl_ca
    # @option options [Integer]  :ssl_pkey
    # @option options [Integer]  :ssl_cert
    # @param    [String]    token
    #   Optional authentication token.
    def initialize( options = nil, token = nil )

        # If given nil use the global defaults.
        options ||= Options.rpc.to_server_options
        @options = options

        super(options.merge(
            serializer: Serializer,
            token:      token
        ))

        return if @reactor.running?
        @reactor.run_in_thread
    end

    def address
        @options[:external_address] || @options[:host]
    end

    def port
        @options[:port]
    end

    def url
        return @options[:socket] if @options[:socket]

        "#{address}:#{port}"
    end

    def start
        super
        @ready = true
    end

    def ready?
        @ready ||= false
    end

end

end
end
end
