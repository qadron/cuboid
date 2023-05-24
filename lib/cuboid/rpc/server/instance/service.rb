module Cuboid
module RPC
class Server
class Instance
module Service

  attr_reader :name
  attr_reader :instance

  def initialize( name, instance )
    @name     = name
    @instance = instance
  end

end

end
end
end
end
