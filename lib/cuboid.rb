require 'rubygems'
require 'bundler/setup'
require 'tmpdir'

require 'oj'
require 'oj_mimic_json'

require_relative 'cuboid/version'

require 'concurrent'
require 'pp'
require 'ap'

def ap( obj )
    super obj, raw: true
end

module Cuboid

    class <<self

        # Runs a minor GC to collect young, short-lived objects.
        #
        # Generally called after analysis operations that generate a lot of
        # new temporary objects.
        def collect_young_objects
            # GC.start( full_mark: false )
        end

        def null_device
            Gem.win_platform? ? 'NUL' : '/dev/null'
        end

        # @return   [Bool]
        def windows?
            Gem.win_platform?
        end

        # @return   [Bool]
        def linux?
            @is_linux ||= RbConfig::CONFIG['host_os'] =~ /linux/
        end

        # @return   [Bool]
        def mac?
            @is_mac ||= RbConfig::CONFIG['host_os'] =~ /darwin|mac os/i
        end

        # @return   [Bool]
        #   `true` if the `CUBOID_PROFILE` env variable is set,
        #   `false` otherwise.
        def profile?
            !!ENV['CUBOID_PROFILE']
        end

        if Cuboid.windows?
            require 'find'
            require 'fileutils'
            require 'Win32API'
            require 'win32ole'

            def get_long_win32_filename( short_name )
                short_name = short_name.dup
                max_path   = 1024
                long_name  = ' ' * max_path

                lfn_size = Win32API.new(
                    "kernel32", 
                    "GetLongPathName",
                    ['P','P','L'],
                    'L'
                ).call( short_name, long_name, max_path )

                (1..max_path).include?( lfn_size ) ? 
                    long_name[0..lfn_size-1] : short_name
            end 
        else
            def get_long_win32_filename( short_name )
                short_name
            end
        end
    end

end

require_relative 'cuboid/banner'
require_relative 'cuboid/ui/output_interface'

# If there's no UI driving us then there's no output interface.
# Chances are that someone is using Engine as a Ruby lib so there's no
# need for a functional output interface, so provide non-functional one.
#
# However, functional or not, the system does depend on one being available.
if !Cuboid::UI.constants.include?(:Output)
    require_relative 'cuboid/ui/output'
end

require_relative 'cuboid/application'

Cuboid::UI::OutputInterface.initialize
