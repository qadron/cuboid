module Cuboid
module UI
module OutputInterface

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
module Controls

    def self.initialize
        @@verbose = false
        @@debug   = 0
    end

    # Enables {#print_verbose} messages.
    #
    # @see #verbose?
    def verbose_on
        @@verbose = true
    end
    alias :verbose :verbose_on

    # Disables {#print_verbose} messages.
    #
    # @see #verbose?
    def verbose_off
        @@verbose = false
    end

    # @return    [Bool]
    def verbose?
        @@verbose
    end

    # Enables {#print_debug} messages.
    #
    # @param    [Integer]   level
    #   Sets the debugging level.
    #
    # @see #debug?
    def debug_on( level = 1 )
        @@debug = level
    end
    alias :debug :debug_on

    # Disables {#print_debug} messages.
    #
    # @see #debug?
    def debug_off
        @@debug = 0
    end

    # @return   [Integer]
    #   Debugging level.
    def debug_level
        @@debug
    end

    # @param    [Integer]   level
    #   Checks against this level.
    #
    # @return   [Bool]
    #
    # @see #debug
    def debug?( level = 1 )
        @@debug >= level
    end

    def debug_level_1?
        debug? 1
    end
    def debug_level_2?
        debug? 2
    end
    def debug_level_3?
        debug? 3
    end
    def debug_level_4?
        debug? 4
    end

end

end
end
end
