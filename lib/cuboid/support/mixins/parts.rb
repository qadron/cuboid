module Cuboid
module Support
module Mixins

module Parts

    def self.included( base )
        dir = Utilities.caller_path( 3 ).split( '.rb', 2 ).first
        Dir.glob( "#{dir}/parts/**/*.rb" ).each { |f| require f }

        parts = base.const_get( :Parts )
        parts.constants.each do |part_name|
            base.include parts.const_get( part_name )
        end
    end

end
end
end
end
