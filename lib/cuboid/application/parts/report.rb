module Cuboid
class Application
module Parts

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
module Report

    def report( results )
        data.report = results
    end

    # @return    [Cuboid::Report]
    #   Scan results.
    def generate_report
        Cuboid::Report.new(
            application:     self.class,
            status:          state.status,
            options:         Options.application,
            data:            data.report,
            start_datetime:  @start_datetime,
            finish_datetime: @finish_datetime
        )
    end

end

end
end
end
