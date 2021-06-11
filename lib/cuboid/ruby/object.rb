# Overloads the {Object} class providing a {#deep_clone} method.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Object

    # Deep-clones self using a Marshal dump-load.
    #
    # @return   [Object]
    #   Duplicate of self.
    def deep_clone
        Marshal.load( Marshal.dump( self ) )
    end

    def rpc_clone
        if self.class.respond_to?( :from_rpc_data )
            self.class.from_rpc_data(
                Cuboid::RPC::Serializer.serializer.load(
                    Cuboid::RPC::Serializer.serializer.dump( to_rpc_data )
                )
            )
        else
            Cuboid::RPC::Serializer.serializer.load(
                Cuboid::RPC::Serializer.serializer.dump( self )
            )
        end
    end

    def to_rpc_data_or_self
        respond_to?( :to_rpc_data ) ? to_rpc_data : self
    end

end
