require 'securerandom'
require 'digest/sha2'
require 'cgi'

module Cuboid

# Includes some useful methods for the system.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
module Utilities

    # @return   [String]
    #   Filename (without extension) of the caller.
    def caller_name
        File.basename( caller_path( 3 ), '.rb' )
    end

    # @return   [String]
    #   Filepath of the caller.
    def caller_path( offset = 2 )
        ::Kernel.caller[offset].split( /:(\d+):in/ ).first
    end

    # @return   [String]    random HEX (SHA2) string
    def random_seed
        @@random_seed ||= generate_token
    end

    # @return   [Fixnum]
    #   Random available port number.
    def available_port( range = nil )
        available_port_mutex.synchronize do
            loop do
                port = self.rand_port( range )
                return port if port_available?( port )
            end
        end
    end

    def self.available_port_mutex
        @available_port_mutex ||= Mutex.new
    end
    available_port_mutex

    # @return   [Integer]
    #   Random port within the user specified range.
    def rand_port( range = nil )
        range ||= [1025, 65535]
        first, last = range
        range = (first..last).to_a

        range[ rand( range.last - range.first ) ]
    end

    def generate_token
        SecureRandom.hex
    end

    # Checks whether the port number is available.
    #
    # @param    [Fixnum]  port
    #
    # @return   [Bool]
    def port_available?( port )
        begin
            socket = ::Socket.new( :INET, :STREAM, 0 )
            socket.bind( ::Socket.sockaddr_in( port, '127.0.0.1' ) )
            socket.close
            true
        rescue Errno::EADDRINUSE, Errno::EACCES
            false
        end
    end

    # @param    [String, Float, Integer]    seconds
    #
    # @return    [String]
    #   Time in `00:00:00` (`hours:minutes:seconds`) format.
    def seconds_to_hms( seconds )
        seconds = seconds.to_i
        [seconds / 3600, seconds / 60 % 60, seconds % 60].
            map { |t| t.to_s.rjust( 2, '0' ) }.join( ':' )
    end

    def hms_to_seconds( time )
        a = [1, 60, 3600] * 2
        time.split( /[:\.]/ ).map { |t| t.to_i * a.pop }.inject(&:+)
    rescue
        0
    end

    def bytes_to_megabytes( bytes )
        (bytes / 1024.0 / 1024.0).round( 3 )
    end

    def bytes_to_kilobytes( bytes )
        (bytes / 1024.0 ).round( 3 )
    end

    # Wraps the `block` in exception handling code and runs it.
    #
    # @param    [Bool]  raise_exception
    #   Re-raise exception?
    # @param    [Block]     block
    def exception_jail( raise_exception = true, &block )
        block.call
    rescue => e
        if respond_to?( :print_error ) && respond_to?( :print_exception )
            print_exception e
            print_error
            print_error 'Parent:'
            print_error  self.class.to_s
            print_error
            print_error 'Block:'
            print_error block.to_s
            print_error
            print_error 'Caller:'
            ::Kernel.caller.each { |l| print_error l }
            print_error '-' * 80
        end

        raise e if raise_exception

        nil
    end

    def regexp_array_match( regexps, str )
        regexps = [regexps].flatten.compact.
            map { |s| s.is_a?( Regexp ) ? s : Regexp.new( s.to_s ) }
        return true if regexps.empty?

        cnt = 0
        regexps.each { |filter| cnt += 1 if filter.match? str }
        cnt == regexps.size
    end

    def remove_constants( mod, skip = [] )
        return if skip.include?( mod )
        return if !(mod.is_a?( Class ) || mod.is_a?( Module )) ||
            !mod.to_s.start_with?( 'Cuboid' )

        parent = Object
        mod.to_s.split( '::' )[0..-2].each do |ancestor|
            parent = parent.const_get( ancestor.to_sym )
        end

        mod.constants.each { |m| mod.send( :remove_const, m ) }
        nil
    end

    extend self

end

end
