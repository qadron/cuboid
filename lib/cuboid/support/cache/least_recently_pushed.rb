module Cuboid
module Support::Cache

# Least Recently Pushed cache implementation.
#
# Discards the least recently pushed entries, in order to make room for newer ones.
#
# This is the cache with best performance across the board.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class LeastRecentlyPushed < Base

    private

    def prune
        @cache.delete( @cache.first.first )
    end

end
end
end
