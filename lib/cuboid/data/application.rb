module Cuboid
class Data

# Data for {Cuboid::Application}.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Application

    # {Application} error namespace.
    #
    # All {Application} errors inherit from and live under it.
    #
    # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
    class Error < Data::Error
    end

    attr_accessor :runtime
    attr_accessor :report

    def statistics
        {
          runtime: !!@runtime,
          report:  !!@report
        }
    end

    def dump( directory )
        FileUtils.mkdir_p( directory )

        d = Cuboid::Application.serializer.dump( @report )
        IO.binwrite( "#{directory}/report", d )

        d = Cuboid::Application.serializer.dump( @runtime )
        IO.binwrite( "#{directory}/runtime", d )
    end

    def self.load( directory )
        application = new
        application.report  = Cuboid::Application.serializer.load( IO.binread( "#{directory}/report" ) )
        application.runtime = Cuboid::Application.serializer.load( IO.binread( "#{directory}/runtime" ) )
        application
    end

    def clear
        @runtime = nil
        @report  = nil
    end

end

end
end
