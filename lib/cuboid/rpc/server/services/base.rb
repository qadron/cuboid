module Cuboid
module RPC
class Server
module Services

module Base

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
