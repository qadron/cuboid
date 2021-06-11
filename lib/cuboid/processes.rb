require 'singleton'
require 'ostruct'

lib = Cuboid::Options.paths.lib
require lib + 'rpc/client/instance'
require lib + 'rpc/client/dispatcher'
require lib + 'rpc/client/scheduler'

lib = Cuboid::Options.paths.lib + 'processes/'
require lib + 'manager'
require lib + 'dispatchers'
require lib + 'instances'
require lib + 'schedulers'
