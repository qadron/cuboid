module Cuboid::OptionGroups

# Holds options for {RPC::Server::Scheduler} servers.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Scheduler < Cuboid::OptionGroup

    # @return   [String]
    #   URL of a {RPC::Server::Scheduler}.
    attr_accessor :url

    # @return   [Array<Integer>]
    #   Range of ports to use when spawning instances, first entry should be
    #   the lowest port number, last the max port number.
    attr_accessor :instance_port_range

    # @return   [Float]
    #   How regularly to check for scan statuses.
    attr_accessor :ping_interval

    set_defaults(
        ping_interval:       5.0,
        instance_port_range: [1025, 65535]
    )

end
end
