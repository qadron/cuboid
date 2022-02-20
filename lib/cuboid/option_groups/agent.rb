module Cuboid::OptionGroups

# Holds options for {RPC::Server::Agent} servers.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Agent < Cuboid::OptionGroup

    STRATEGIES = Set.new([:horizontal, :vertical, :direct])

    # @return   [String]
    #   URL of a {RPC::Server::Agent}.
    attr_accessor :url

    # @return   [Array<Integer>]
    #   Range of ports to use when spawning instances, first entry should be
    #   the lowest port number, last the max port number.
    attr_accessor :instance_port_range

    # @return   [String]
    #   The URL of a peering {RPC::Server::Agent}, applicable when
    #   {RPC::Server::Agent} are connected to each other to form a Grid.
    #
    # @see RPC::Server::Agent::Node
    attr_accessor :peer

    # @return   [Float]
    #   How regularly to check for peer statuses.
    attr_accessor :ping_interval

    # @return   [String]
    #   Agent name.
    attr_accessor :name

    attr_accessor :strategy

    set_defaults(
        strategy:            :horizontal,
        ping_interval:       5.0,
        instance_port_range: [1025, 65535]
    )

    def strategy=( type )
        return @strategy = defaults[:strategy] if !type

        type = type.to_sym
        if !STRATEGIES.include? type
            fail ArgumentError, "Unknown strategy type: #{type}"
        end

        @strategy = type
    end

end
end
