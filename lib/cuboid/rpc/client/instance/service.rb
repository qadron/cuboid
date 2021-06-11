module Cuboid

module RPC
class Client
class Instance

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Proxy < Arachni::RPC::Proxy

    def initialize( client )
        super client, 'instance'
    end

    translate :status do |status|
        status.to_sym if status
    end

    translate :progress do |data|
        data = data.my_symbolize_keys
        data[:status] = data[:status].to_sym
        data
    end

    translate :abort_and_generate_report do |data|
        Report.from_rpc_data data
    end

    translate :generate_report do |data|
        Report.from_rpc_data data
    end

end

end
end
end
end
