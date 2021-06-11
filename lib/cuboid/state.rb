module Cuboid

# Stores and provides access to the state of the system.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class State

    # {State} error namespace.
    #
    # All {State} errors inherit from and live under it.
    #
    # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
    class Error < Cuboid::Error
    end

    require_relative 'state/options'
    require_relative 'state/application'

class <<self

    # @return     [Options]
    attr_accessor :options

    # @return     [Framework]
    attr_accessor :application

    def reset
        @options        = Options.new
        @application    = Application.new
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
    #
    # @return   [String]
    #   Location of the directory.
    def dump( directory )
        FileUtils.mkdir_p( directory )

        each do |name, state|
            state.dump( "#{directory}/#{name}/" )
        end

        directory
    end

    # @param    [String]    directory
    #   Location of the dump directory.
    #
    # @return   [State]
    #   `self`
    def load( directory )
        each do |name, state|
            send( "#{name}=", state.class.load( "#{directory}/#{name}/" ) )
        end

        self
    end

    # Clears all states.
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
            attribute
        end.compact.map(&:to_sym)
    end

end

reset
end
end
