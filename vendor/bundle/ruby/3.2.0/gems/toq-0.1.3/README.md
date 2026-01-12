# Toq

<table>
    <tr>
        <th>Version</th>
        <td>0.0.4</td>
    </tr>
    <tr>
        <th>Github page</th>
        <td><a href="http://github.com/qadron/toq">http://github.com/qadron/toq</a></td>
     </tr>
    <tr>
        <th>Code Documentation</th>
        <td><a href="http://rubydoc.info/github/qadron/toq/">http://rubydoc.info/github/qadron/toq/</a></td>
    </tr>
    <tr>
       <th>Author</th>
       <td><a href="mailto:tasos.laskos@gmail.com">Tasos Laskos</a></td>
    </tr>
    <tr>
        <th>Copyright</th>
        <td> 2025 <a href="mailto:tasos.laskos@gmail.com">Tasos Laskos</a></td>
    </tr>
    <tr>
        <th>License</th>
        <td><a href="file.LICENSE.html">3-clause BSD</a></td>
    </tr>
</table>

## Synopsis

Toq is a simple and lightweight Remote Procedure Call protocol and implementation.

This implementation is based on [Raktr](https://github.com/qadron/raktr).

## Features

 - Extremely lightweight.
 - Very simple design.
 - TLS encryption.
 - Configurable serializer.
    - Can intercept RPC responses and translate them into native objects for
        when using serializers that only support basic types, like JSON or MessagePack.
 - Token-based authentication.
 - Pure-Ruby.
 - Multi-platform, tested on:
    - Linux
    - OSX
    - Windows

## Installation

    gem install toq

## Running the Specs

    bundle install
    rake spec

## Protocol specifications

You can find the RPC protocol specification at the
[Wiki](https://github.com/Arachni/arachni-rpc/wiki).

## License

Toq is provided under the 3-clause BSD license.
See the `LICENSE` file for more information.
