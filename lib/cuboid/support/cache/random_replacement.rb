module Cuboid
module Support::Cache

# Random Replacement cache implementation.
#
# Discards entries at random in order to make room for new ones.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class RandomReplacement < Base

    private

    def prune
        @cache.delete( @cache.keys.sample )
    end

end

end
end
