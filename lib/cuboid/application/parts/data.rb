module Cuboid
class Application
module Parts
# Provides access to {Cuboid::Data::Framework} and helpers.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
module Data

    # @return   [Data::Application]
    def data
        Cuboid::Data.application
    end

end

end
end
end
