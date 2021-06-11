module Cuboid
module UI
module OutputInterface

# These methods need to be implemented by the driving UI.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
module Abstract

    class Error < Cuboid::UI::OutputInterface::Error

        # Raised when trying to use an output method that has not been implemented.
        class MissingImplementation < Error
        end

    end

    # @abstract
    def print_error( message = '' )
        fail Error::MissingImplementation
    end

    # @abstract
    def print_bad( message = '' )
        fail Error::MissingImplementation
    end

    # @abstract
    def print_status( message = '' )
        fail Error::MissingImplementation
    end

    # @abstract
    def print_info( message = '' )
        fail Error::MissingImplementation
    end

    # @abstract
    def print_ok( message = '' )
        fail Error::MissingImplementation
    end

    # @abstract
    def print_verbose( message = '' )
        fail Error::MissingImplementation
    end

    # @abstract
    def print_line( message = '' )
        fail Error::MissingImplementation
    end

    # @abstract
    def print_debug( message = '', level = 1 )
        fail Error::MissingImplementation
    end

    # @abstract
    def output_provider_file
        # __FILE__
        fail Error::MissingImplementation
    end

end

end
end
end
