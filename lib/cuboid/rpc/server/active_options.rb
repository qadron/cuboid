module Cuboid
module RPC
class Server

# It, for the most part, forwards calls to {Cuboid::Options} and intercepts
# a few that need to be updated at other places throughout the framework.
#
# @private
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class ActiveOptions

    def initialize
        @options = Cuboid::Options.instance

        (@options.public_methods( false ) - public_methods( false ) ).each do |m|
            self.class.class_eval do
                define_method m do |*args|
                    @options.send( m, *args )
                end
            end
        end
    end

    # @see Cuboid::Options#set
    def set( options )
        @options.set( options )
        true
    end

    def to_h
        @options.to_rpc_data
    end

end

end
end
end
