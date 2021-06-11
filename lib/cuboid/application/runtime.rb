module Cuboid
class Application

class Runtime

    def state
        Cuboid::Application.application.state.runtime
    end

    def state=( d )
        Cuboid::Application.application.state.runtime = d
    end

    def data
        Cuboid::Application.application.data.runtime
    end

    def data=( d )
        Cuboid::Application.application.data.runtime = d
    end

end

end
end
