require_relative 'mixins/unix'

module Cuboid

class System
module Platforms
class OSX < Base
    include Mixins::Unix

    # @return   [Integer]
    #   Amount of free RAM in bytes.
    def memory_free
        pagesize * memory.free
    end

    class <<self
        def current?
            Cuboid.mac?
        end
    end

end
end
end
end
