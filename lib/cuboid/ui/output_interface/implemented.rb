module Cuboid
module UI
module OutputInterface

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
module Implemented

    # Prints the backtrace of an exception as error messages.
    #
    # @param    [Exception] e
    def print_error_backtrace( e )
        e.backtrace.each { |line| print_error( line ) }
    end

    def print_exception( e )
        print_error "[#{e.class}] #{e}"
        print_error_backtrace( e )
    end

    def print_debug_level_1( str = '' )
        print_debug( str, 1 )
    end

    def print_debug_level_2( str = '' )
        print_debug( str, 2 )
    end

    def print_debug_level_3( str = '' )
        print_debug( str, 3 )
    end

    def print_debug_level_4( str = '' )
        print_debug( str, 4 )
    end

    def print_debug_exception( e, level = 1 )
        return if !debug?

        print_debug( "[#{e.class}] #{e}", level )
        print_debug_backtrace( e, level )
    end

    # Prints the backtrace of an exception as debugging messages.
    #
    # @param    [Exception] e
    #
    # @see #debug?
    # @see #debug
    def print_debug_backtrace( e, level = 1 )
        return if !debug?
        e.backtrace.each { |line| print_debug( line, level ) }
    end

end

end
end
end
