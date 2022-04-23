module Cuboid::OptionGroups

# Holds {Engine::RPC::Client} and {Engine::RPC::Server} options.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class RPC < Cuboid::OptionGroup

    # @return   [String]
    #   Path to the UNIX socket to use for RPC communication.
    #
    # @see RPC::Server::Base
    attr_accessor :server_socket

    # @return   [String]
    #   Hostname or IP address for the RPC server.
    #
    # @see RPC::Server::Base
    attr_accessor :server_address

    # @return   [String]
    #   External (hostname or IP) address for the RPC server to advertise.
    attr_accessor :server_external_address

    # @return   [Integer]
    #   RPC server port.
    #
    # @see RPC::Server::Base
    attr_accessor :server_port

    # @return   [String]
    #   Path to an SSL certificate authority file in PEM format.
    #
    # @see RPC::Server::Base
    # @see RPC::Client::Base
    attr_accessor :ssl_ca

    # @return   [String]
    #   Path to a server SSL private key in PEM format.
    #
    # @see RPC::Server::Base
    attr_accessor :server_ssl_private_key

    # @return   [String]
    #   Path to server SSL certificate in PEM format.
    #
    # @see RPC::Server::Base
    attr_accessor :server_ssl_certificate

    # @return   [String]
    #   Path to a client SSL private key in PEM format.
    #
    # @see RPC::Client::Base
    attr_accessor :client_ssl_private_key

    # @return   [String]
    #   Path to client SSL certificate in PEM format.
    #
    # @see RPC::Client::Base
    attr_accessor :client_ssl_certificate

    # @return [Integer]
    #   Maximum retries for failed RPC calls.
    #
    # @see RPC::Client::Base
    attr_accessor :client_max_retries

    # @note This should be permanently set to `1`, otherwise it will cause issues
    #   with the scheduling of the workload distribution of multi-Instance scans.
    #
    # @return [Integer]
    #   Amount of concurrently open connections for each RPC client.
    #
    # @see RPC::Client::Base
    attr_accessor :connection_pool_size

    set_defaults(
        connection_pool_size: 1,
        server_address:       '127.0.0.1',
        server_port:          7331
    )

    def url
        "#{server_address}:#{server_port}"
    end

    def to_client_options
        {
            connection_pool_size: connection_pool_size,
            max_retries:          client_max_retries,
            ssl_ca:               ssl_ca,
            ssl_pkey:             client_ssl_private_key,
            ssl_cert:             client_ssl_certificate
        }
    end

    def to_server_options
        {
            host:             server_address,
            external_address: server_external_address,
            port:             server_port,
            socket:           server_socket,
            ssl_ca:           ssl_ca,
            ssl_pkey:         server_ssl_private_key,
            ssl_cert:         server_ssl_certificate
        }
    end

end
end
