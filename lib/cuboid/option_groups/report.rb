module Cuboid::OptionGroups

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Report < Cuboid::OptionGroup

    # @return    [String]
    #   Directory or file path where to store the scan report.
    attr_accessor :path

    def initialize
        @default_path = self.path = default_path
    end

    def path=( path )
        return @path = @default_path if !path

        if path.end_with?( '/' ) && !File.exist?( path )
            raise ArgumentError,
                  "Snapshot location does not exist: #{path}"
        end

        path = File.expand_path( path )
        if File.directory? path
            path += '/' if !path.end_with? '/'
        end

        @path = path
    end

    def default_path
        Paths.config['reports']
    end

    def defaults
        { path: default_path }
    end

end
end
