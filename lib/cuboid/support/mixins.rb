module Cuboid::Mixins
end

lib = Cuboid::Options.paths.mixins
require lib + 'observable'
require lib + 'terminal'
require lib + 'profiler'
require lib + 'parts'
