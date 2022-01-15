require 'fileutils'
require 'tmpdir'

module Cuboid::OptionGroups

# Holds paths to the directories of various system components.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Paths < Cuboid::OptionGroup

    TMPDIR_SUFFIX = 'Cuboid_'

    [
        :root,
        :logs,
        :reports,
        :executables,
        :services,
        :lib,
        :support,
        :mixins,
        :snapshots
    ].each do |type|
        attr_accessor type

        define_method "#{type}=" do |path|
            if !path
                return instance_variable_set :"@#{type}", defaults[type]
            end

            path += '/' if !path.end_with? '/'

            if !File.directory? path
                raise ArgumentError,
                      "#{type.to_s.capitalize} directory does not exist: #{path}"
            end

            instance_variable_set :"@#{type}", path
        end
    end

    #   @return [String]
    attr_accessor :application

    # @!attribute root
    #   @return [String]

    # @!attribute lib
    #   @return [String]

    # @!attribute support
    #   @return [String]

    # @!attribute mixins
    #   @return [String]

    # @!attribute components
    #   @return [String]

    # @!attribute services
    #   @return [String]

    # @!attribute reports
    #   @return [String]
    #       Report storage.

    # @!attribute snapshots
    #   @return [String]
    #       Snapshot storage.

    # @!attribute executables
    #   @return [String]
    #       System processes (instance, dispatcher, browser, etc.).

    def initialize
        @root = self.root_path
        FileUtils.mkdir_p home_path

        @snapshots = self.config['snapshots'] || home_path + '/snapshots/'
        FileUtils.mkdir_p @snapshots

        @reports = self.config['reports'] || home_path + '/reports/'
        FileUtils.mkdir_p @reports

        if ENV['CUBOID_LOGDIR'].to_s != ''
            @logs = "#{ENV['CUBOID_LOGDIR']}/"
        elsif self.config['logs']
            @logs = self.config['logs']
        else
            @logs = "#{home_path}/logs/"
            FileUtils.mkdir_p @logs
        end

        @lib         = @root    + 'lib/cuboid/'
        @executables = @lib     + 'processes/executables/'
        @support     = @lib     + 'support/'
        @mixins      = @support + 'mixins/'

        instance_variables.each do |iv|
            defaults[iv.to_s.sub( '@', '' ).to_sym] = instance_variable_get( iv )
        end

        tmpdir
    end

    def home_path
        @home_path ||= "#{ENV['HOME']}/.cuboid/"
    end

    def root_path
        self.class.root_path
    end

    # @return   [String]
    #   Root path of the engine.
    def self.root_path
        File.expand_path( File.dirname( __FILE__ ) + '/../../..' ) + '/'
    end

    def os_tmpdir
        return @os_tmpdir if @os_tmpdir

        if config['tmpdir'].to_s.empty?
            # On MS Windows Dir.tmpdir can return the path with a shortname,
            # better avoid that as it can be insonsistent with other paths.
            @os_tmpdir = Cuboid.get_long_win32_filename( Dir.tmpdir )
        else
            @os_tmpdir = Cuboid.get_long_win32_filename( config['tmpdir'] )
        end
    end

    def tmpdir
        return @tmpdir if @tmpdir

        dir = tmp_dir_for( Process.pid )

        FileUtils.mkdir_p dir
        at_exit do
            FileUtils.rm_rf dir
        end

        @tmpdir = dir
    end

    def tmp_dir_for( pid )
        "#{os_tmpdir}/#{TMPDIR_SUFFIX}#{pid}"
    end

    def config
        self.class.config
    end

    def self.paths_config_file
        Cuboid.get_long_win32_filename "#{root_path}config/paths.yml"
    end

    def self.clear_config_cache
        @config = nil
    end

    def self.config
        return @config if @config

        if !File.exist?( paths_config_file )
            @config = {}
        else
            @config = YAML.load( IO.read( paths_config_file ) )
        end

        @config.dup.each do |category, dir|
            if dir.to_s.empty?
                @config.delete( category )
                next
            end

            dir = Cuboid.get_long_win32_filename( dir )

            if !Cuboid.windows?
                dir.gsub!( '~', ENV['HOME'] )
            end

            dir << '/' if !dir.end_with?( '/' )

            @config[category] = dir

            FileUtils.mkdir_p dir
        end

        @config
    end

end
end
