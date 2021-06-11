require 'set'

module Cuboid
module Support::Filter

# Filter based on a Set.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Set < Base

    # @param    (see Base#initialize)
    def initialize(*)
        super
        @collection = ::Set.new
    end

    def to_rpc_data
        [@options, @collection.to_a]
    end

    def self.from_rpc_data( data )
        options, items = data
        new( options ).merge items
    end

end

end
end
