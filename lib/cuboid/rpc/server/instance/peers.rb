module Cuboid
module RPC
class Server
class Instance

class Peers
  include Enumerable

  def initialize
    @peers    = {}
  end

  def set( peer_info )
    peer_info.each do |url, token|
      next if url == self.self_url
      @peers[url] = Cuboid::Application.application.connect( url: url, token: token )
    end

    nil
  end

  def each( &block )
    @peers.each do |_, client|
      block.call client
    end
  end

  def self_url
    Cuboid::Options.rpc.url
  end

end

end
end
end
end
