require 'cuboid/error'

module Cuboid
module UI

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Error < Cuboid::Error
end

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
module OutputInterface

    # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
    class Error < Cuboid::UI::Error
    end

    require_relative 'output_interface/abstract'
    require_relative 'output_interface/implemented'

    require_relative 'output_interface/error_logging'
    require_relative 'output_interface/controls'
    require_relative 'output_interface/personalization'

    # These output methods need to be implemented by the driving UI.
    include Abstract
    # These output method implementations depend on the Abstract ones.
    include Implemented

    include ErrorLogging
    include Controls
    include Personalization

    # Must be called after the entire {Cuboid} environment has been loaded.
    def self.initialize
        Controls.initialize
        ErrorLogging.initialize
    end

    extend self
end

end
end
