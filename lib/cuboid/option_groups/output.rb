module Cuboid::OptionGroups

# {Cuboid::UI::Output} options.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Output < Cuboid::OptionGroup

    # @return   [Bool]
    #   `true` if the output of the RPC instances should be redirected to a
    #   file, `false` otherwise.
    attr_accessor :reroute_to_logfile

end
end
