module Cuboid
module UI

# The system needs an {OutputInterface interface} as a {Cuboid::UI::Output}
# module and every UI should provide one.
#
# This one however is in case that one isn't available and it's basically
# a black hole that will only print and log errors and nothing else.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
module Output
    include OutputInterface

    def print_error( message = '' )
        msg = "#{caller_location} #{message}"

        $stderr.puts msg
        log_error msg
    end

    def print_bad(*)
    end

    def print_status(*)
    end

    def print_info(*)
    end

    def print_ok(*)
    end

    def print_debug(*)
    end

    def print_verbose(*)
    end

    def print_line(*)
    end

    private

    def output_provider_file
        __FILE__
    end

    extend self
end

end
end
