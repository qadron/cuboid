require 'ap'
require 'timeout'
require_relative '../lib/toq'
require_relative 'servers/server'

def cwd
    File.expand_path( File.dirname( __FILE__ ) )
end

def start_client( opts )
    Toq::Client.new( opts )
end

def quiet_spawn( file )
    path = File.join( File.expand_path( File.dirname( __FILE__ ) ), 'servers', "#{file}.rb" )
    Process.spawn RbConfig.ruby, path#, out: '/dev/null'
end

server_pids = []
RSpec.configure do |config|
    config.color = true
    config.add_formatter :documentation

    # config.filter_run_including focus: true

    config.before( :suite ) do
        File.delete( '/tmp/toq-rpc-test' ) rescue nil

        files = %w(basic with_ssl_primitives)
        files << 'unix_socket' if Raktr.supports_unix_sockets?

        files.each do |name|
            server_pids << quiet_spawn( name ).tap { |pid| Process.detach( pid ) }
        end
        sleep 1
    end

    config.after( :suite ) do
        server_pids.each { |pid| Process.kill( 'KILL', pid ) }
    end
end
