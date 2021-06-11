module Cuboid

# Stores and provides access to the data of the system.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Data

    # {Data} error namespace.
    #
    # All {Data} errors inherit from and live under it.
    #
    # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
    class Error < Cuboid::Error
    end

    require_relative 'data/application'

class <<self

    # @return     [Framework]
    attr_accessor :application

    def reset
        @application = Application.new
    end

    def statistics
        stats = {}
        each do |attribute|
            stats[attribute] = send(attribute).statistics
        end
        stats
    end

    # @param    [String]    directory
    #   Location of the dump directory.
    # @return   [String]
    #   Location of the dump directory.
    def dump( directory )
        FileUtils.mkdir_p( directory )

        each do |name, state|
            state.dump( "#{directory}/#{name}/" )
        end

        directory
    end

    # @param    [String]    directory
    #   Location of the dump directory.
    # @return   [Data]     `self`
    def load( directory )
        each do |name, state|
            send( "#{name}=", state.class.load( "#{directory}/#{name}/" ) )
        end

        self
    end

    # Clears all data.
    def clear
        each { |_, state| state.clear }
        self
    end

    private

    def each( &block )
        accessors.each do |attr|
            block.call attr, send( attr )
        end
    end

    def accessors
        instance_variables.map do |ivar|
            attribute = "#{ivar.to_s.gsub('@','')}"
            next if !methods.include?( :"#{attribute}=" )
            attribute.to_sym
        end.compact
    end

end

reset
end
end
