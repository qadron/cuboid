class WebServerManager
    include Singleton
    include Cuboid::Utilities

    attr_reader   :lib
    attr_accessor :address

    def initialize
        @lib     = "#{support_path}/servers/"
        @servers = {}
        @address = Socket.gethostname

        Dir.glob( File.join( @lib + '**', '*.rb' ) ) do |path|
            @servers[normalize_name( File.basename( path, '.rb' ) )] = {
                path: path
            }
        end
    end

    def spawn( name )
        server_info = data_for( name )

        10.times do
            server_info[:port] = Cuboid::Utilities.available_port
            server_info[:pid]  = Process.spawn(
                RbConfig.ruby, server_info[:path],
                '-p', server_info[:port].to_s,
                '-o', address_for( name )
            )
            Process.detach server_info[:pid]

            begin
                Timeout.timeout( 10 ) { sleep 0.1 while !up?( name ) }

                return url_for( name, false )
            rescue Timeout::Error
                kill name
            end
        end

        abort "Server '#{name}' never started!"
    end

    def url_for( name, lazy_start = true )
        spawn( name ) if lazy_start && !up?( name )

        "#{protocol_for( name )}://#{address_for( name )}:#{port_for( name )}"
    end

    def address_for( name )
        @address
    end

    def port_for( name )
        data_for( name )[:port]
    end

    def protocol_for( name )
        name.to_s.include?( 'https' ) ? 'https' : 'http'
    end

    def kill( name )
        server_info = data_for( name )
        return if !server_info[:pid]

        r = process_kill( server_info[:pid] )

        if r
            server_info.delete( :pid )
            server_info.delete( :port )
        end

        r
    end

    def killall
        @servers.keys.each { |name| kill name }
        nil
    end

    def up?( name )
        return false if !data_for(name)[:port]

        Typhoeus.get(
            url_for( name, false ),
            ssl_verifypeer: false,
            ssl_verifyhost: 0,
            forbid_reuse:   true
        ).code != 0
    end

    def self.method_missing( sym, *args, &block )
        if instance.respond_to?( sym )
            instance.send( sym, *args, &block )
        else
            super( sym, *args, &block )
        end
    end

    def self.respond_to?( m )
        super( m ) || instance.respond_to?( m )
    end

    private

    def normalize_name( name )
        name.to_s.to_sym
    end

    def data_for( name )
        @servers[normalize_name( name )]
    end

    def set_data_for(name, data)
        @servers[normalize_name(name)] = data
    end

end
