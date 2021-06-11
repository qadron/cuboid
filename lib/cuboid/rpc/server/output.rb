module Cuboid
module UI

# RPC Output interface.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
module Output
    include OutputInterface

    def self.initialize
        @@reroute_to_file = false
        @@error_buffer    = []
    end
    initialize

    # @param    [String]    str
    def log_error( str = '' )
        super( str )
        @@error_buffer << str
    end

    def error_buffer
        @@error_buffer
    end

    def print_error( str = '' )
        log_error( str )
        push_to_output_buffer( error: str )
    end

    def print_bad( str = '' )
        push_to_output_buffer( bad: str )
    end

    def print_status( str = '' )
        push_to_output_buffer( status: str )
    end

    def print_info( str = '' )
        push_to_output_buffer( info: str )
    end

    def print_ok( str = '' )
        push_to_output_buffer( ok: str )
    end

    def print_debug( str = '', level = 1 )
        return if !debug?( level )
        push_to_output_buffer( debug: str )
    end

    def print_verbose( str = '' )
        push_to_output_buffer( verbose: str )
    end

    def print_line( str = '' )
        push_to_output_buffer( line: str )
    end

    def reroute_to_file( file )
        @@reroute_to_file = file
    end

    def reroute_to_file?
        @@reroute_to_file
    end

    def output_provider_file
        __FILE__
    end

    private

    def push_to_output_buffer( msg )
        return if !@@reroute_to_file

        # This is stupid, keep a handle open and close it on exit like with the
        # error log file.
        File.open( @@reroute_to_file, 'a+' ) do |f|
            type = msg.keys[0]
            str  = msg.values[0]

            f.write( "[#{Time.now.asctime}] [#{type}]  #{str}\n" )
        end
    end

    extend self

end

end
end
