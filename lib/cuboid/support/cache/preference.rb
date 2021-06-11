module Cuboid
module Support::Cache

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Preference < Base

    def prefer( &block )
        @preference = block
    end

    private

    def store_with_internal_key( k, v )
        prune if capped? && (size > max_size - 1)

        _store( k, v )
    end

    def find_preference
        @preference.call
    end

    def prune
        preferred = find_preference
        delete( preferred ) if preferred
    end

end

end
end
