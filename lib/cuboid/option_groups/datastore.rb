require 'ostruct'

module Cuboid::OptionGroups

# Generic OpenStruct-based class for general purpose data storage.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Datastore < Cuboid::OptionGroup

    def initialize
        @source = OpenStruct.new
    end

    def method_missing( method, *args, &block )
        @source.send( method, *args, &block )
    end

    def to_h
        @source.marshal_dump
    end

end
end
