module Cuboid
module Support::Cache

# Least Recently Used cache implementation.
#
# Generally, the most desired mode under most circumstances.
# Discards the least recently used entries in order to make room for newer ones.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class LeastRecentlyUsed < LeastRecentlyPushed

    private

    def get_with_internal_key( k )
        if !@cache.include? k
            @misses += 1
            return
        end

        renew( k )

        super k
    end

    def renew( internal_key )
        @cache[internal_key] = @cache.delete( internal_key )
    end

end
end
end
