# 0.2.6

* `Application.serializer` now defaults to JSON for REST API compatibility.

# 0.2.5

* `RPC::Server::Services::Base` => `RPC::Server::Instance::Service`
* Added `RPC::Server::Instance::Peers` as a helper to iterate over peer `Instances`.

# 0.2.4.2

* Instance RPC services now decorated with `Server::Services::Base`.

# 0.2.4.1

* `Application`: Added `#application=` to help with inheritance.

# 0.2.4

* Made `Server::Instance` services accessible from `Application`.

# 0.2.3

* Simplified convergence of P2P mesh network.

# 0.2.2

* `Processes::Manager`
  * `#spawn` -- Handle `Interrupt` more gracefully.

# 0.2.1

* `Processes::Manager`
  * `#spawn` -- Handle exited child more gracefully.

# 0.2

* `Processes::Manager`
  * `#spawn` -- Daemonize servers optionally -- default turned to `false`.

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
