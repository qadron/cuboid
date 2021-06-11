require_relative 'report'

module Cuboid::OptionGroups

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Snapshot < Report

    def default_path
        Paths.config['snapshots']
    end

end
end
