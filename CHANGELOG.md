# 0.1.8

* `Processes::Manager`
  * `#find_in_applications` -- Also include `PATH` search.

# 0.1.7

* `Application`
  * Added `#shutdown` callback method to handle RPC server shutdowns.

# 0.1.6.1

* `OptionGroups::RPC`: Added `#url`.

# 0.1.5

* Fixed relative path for application source path detection.

# 0.1.3

* Replaced `Arachni::RPC` and `Arachni::Reactor` with `Toq` and `Raktr`.

# 0.1.0

* `Dispatcher` => `Agent`
* `Dispatcher#dispatch` => `Agent#spawn`
* `neighbour` => `peer`
