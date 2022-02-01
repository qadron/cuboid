require_relative 'rpc/serializer'
require 'time'

module Cuboid

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Report
    include Utilities

    EXTENSION = 'crf'
    
    INTEGER_SIZE = 4

    UNPACK = 'N'
    
    # @return    [String]
    #   {Cuboid::VERSION}
    attr_accessor :version

    attr_accessor :application

    # @return    [Symbol]
    attr_accessor :status

    # @return    [String]
    #   Scan seed.
    attr_accessor :seed

    # @return    [Hash]
    #   {Options#to_h}
    attr_accessor :options

    # Arbitrary data from the Application.
    attr_accessor :data

    # @return    [Time]
    #   The date and time when the scan started.
    attr_accessor :start_datetime

    # @return    [Time]
    #   The date and time when the scan finished.
    attr_accessor :finish_datetime

    def initialize( options = {} )
        options.each { |k, v| send( "#{k}=", v ) }

        @version ||= Cuboid::VERSION

        @start_datetime  ||= Time.now
        @finish_datetime ||= Time.now
    end

    # @note If no {#finish_datetime} has been provided, it will use `Time.now`.
    #
    # @return   [String]
    #   `{#start_datetime} - {#finish_datetime}` in `00:00:00`
    #   (`hours:minutes:seconds`) format.
    def delta_time
        seconds_to_hms( (@finish_datetime || Time.now) - @start_datetime )
    end

    # @param    [String]    report
    #   Location of the report.
    #
    # @return   [Hash]
    #   {#summary} associated with the given report.
    def self.read_summary( report )
        File.open( report ) do |f|
            f.seek -INTEGER_SIZE, IO::SEEK_END
            summary_size = f.read( INTEGER_SIZE ).unpack( 'N' ).first

            f.seek -summary_size-INTEGER_SIZE, IO::SEEK_END
            summary = RPC::Serializer.load( f.read( summary_size ) ).my_symbolize_keys
            summary[:application] = ObjectSpace.const_get( summary[:application].to_sym )
            summary
        end
    end

    # Loads and a {#save saved} {Report} object from file.
    #
    # @param    [String]    file
    #   File created by {#save}.
    #
    # @return    [Report]
    #   Loaded instance.
    def self.load( file )
        File.open( file, 'rb' ) do |f|
            from_rpc_data RPC::Serializer.load( self.crf_without_summary( f ) )
        end
    end

    # @param    [String]    location
    #   Location for the {#to_crf dumped} report file.
    #
    # @return   [String]
    #   Absolute location of the report.
    def save( location = nil )
        if !location
            location = default_filename
        elsif File.directory? location
            location += "/#{default_filename}"
        end

        # We do it this way to prevent FS watchers from grabbing files that
        # are in the process of being written and thus partial.
        tmp = "#{Options.paths.tmpdir}/#{Utilities.generate_token}"
        IO.binwrite( tmp, to_crf )
        FileUtils.mv tmp, location

        File.expand_path( location )
    end

    # @return   [String]
    #   Report serialized in the Cuboid Report format.
    def to_crf
        crf = RPC::Serializer.dump( self )

        sum = summary
        sum[:application] = sum[:application].to_s
        # Append metadata to the end of the dump.
        metadata = RPC::Serializer.dump( sum )
        crf << [metadata, metadata.size].pack( "a*#{UNPACK}" )

        crf
    end

    def self.from_crf( data )
        from_rpc_data RPC::Serializer.load(
          self.crf_without_summary( StringIO.new( data ) )
        )
    end

    # @return   [Hash]
    #   Hash representation of `self`.
    def to_h
        h = {
            application:     @application,
            version:         @version,
            status:          @status,
            seed:            @seed,
            data:            @data,
            options:         Cuboid::Options.hash_to_rpc_data( @options ),
            start_datetime:  @start_datetime.to_s,
            finish_datetime: @finish_datetime.to_s,
            delta_time:      delta_time
        }
    end
    alias :to_hash :to_h

    # @return   [Hash]
    #   Summary data of the report.
    def summary
        {
            application:     @application,
            version:         @version,
            status:          @status,
            seed:            @seed,
            start_datetime:  @start_datetime.to_s,
            finish_datetime: @finish_datetime.to_s,
            delta_time:      delta_time
        }
    end

    # @return   [Hash]
    #   Data representing this instance that are suitable the RPC transmission.
    def to_rpc_data
        data = {}
        instance_variables.each do |ivar|
            data[ivar.to_s.gsub('@','')] = instance_variable_get( ivar )
        end

        data['application'] = data['application'].to_s
        data['data']        = @application.serializer.dump( data['data'] )
        data['options']     = @application.serializer.dump( data['options'] )

        data['start_datetime']  = data['start_datetime'].to_s
        data['finish_datetime'] = data['finish_datetime'].to_s
        data
    end

    # @param    [Hash]  data    {#to_rpc_data}
    # @return   [DOM]
    def self.from_rpc_data( data )
        data['start_datetime']  = Time.parse( data['start_datetime'] )
        data['finish_datetime'] = Time.parse( data['finish_datetime'] )

        data['application'] = ObjectSpace.const_get( data['application'] )
        data['data']        = data['application'].serializer.load( data['data'] )
        data['options']     = data['application'].serializer.load( data['options'] )

        new data
    end

    def ==( other )
        hash == other.hash
    end

    def hash
        h = to_hash
        [:start_datetime, :finish_datetime, :delta_datetime].each do |k|
            h.delete k
        end
        h.hash
    end

    private

    def self.crf_without_summary( io )
        io.seek -INTEGER_SIZE, IO::SEEK_END
        summary_size = io.read( INTEGER_SIZE ).unpack( UNPACK ).first

        io.rewind
        io.read( io.size - summary_size - INTEGER_SIZE )
    end

    def default_filename
        "Cuboid #{@finish_datetime.to_s.gsub( ':', '_' )}.#{EXTENSION}"
    end

end
end
