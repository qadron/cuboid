module Cuboid
module Support

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Glob

    def self.to_regexp( glob )
        escaped = Regexp.escape( glob ).gsub( '\*', '.*?' )
        Regexp.new( "^#{escaped}$", Regexp::IGNORECASE )
    end

    attr_reader :regexp

    def initialize( glob )
        @regexp = self.class.to_regexp( glob )
    end

    def =~( str )
        @regexp.match? str
    end
    alias :matches? :=~
    alias :match? :matches?

end

end
end
