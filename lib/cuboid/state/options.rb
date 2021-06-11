module Cuboid
class State

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Options

    def statistics
        {}
    end

    def dump( directory )
        FileUtils.mkdir_p( directory )
        Cuboid::Options.save( "#{directory}/options" )
    end

    def self.load( directory )
        Cuboid::Options.load( "#{directory}/options" )
        new
    end

    def clear
    end

end

end
end
