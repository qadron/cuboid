module Cuboid

require Options.paths.lib + 'rpc/server/output'

module RPC

# Agent node class, helps maintain a list of all available Agents in
# the grid and announce itself to peering Agents.
#
# As soon as a new Node is fired up it checks-in with its peer and grabs
# a list of all available peers.
#
# As soon as it receives the peer list it then announces itself to them.
#
# Upon convergence there will be a grid of Agents each one with its own
# copy of all available Agent URLs.
#
# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
class Server::Agent::Node
    include UI::Output

    # Initializes the node by:
    #
    #   * Adding the peer (if the user has supplied one) to the peer list.
    #   * Getting the peer's peer list and appending them to its own.
    #   * Announces itself to the peer and instructs it to propagate our URL
    #     to the others.
    #
    # @param    [Cuboid::Options]    options
    # @param    [Server::Base]    server
    #   Agent's RPC server.
    # @param    [String]              logfile
    #   Where to send the output.
    def initialize( options, server, logfile = nil )
        @options = options
        @server  = server
        @url     = @server.url

        reroute_to_file( logfile ) if logfile

        print_status 'Initializing grid node...'

        @dead_nodes = Set.new
        @peers = Set.new
        @nodes_info_cache = []

        if (peer = @options.agent.peer)
            # Grab the peer's peers.
            connect_to_peer( peer ).peers do |urls|
                if urls.rpc_exception?
                    add_dead_peer( peer )
                    print_info "Neighbour seems dead: #{peer}"
                    add_dead_peer( peer )
                    next
                end

                # Add peer and announce it to everyone.
                add_peer( peer, true )

                urls.each { |url| @peers << url if url != @url }
            end
        end

        print_status 'Node ready.'

        log_updated_peers

        Raktr.global.at_interval( @options.agent.ping_interval ) do
            ping
            check_for_comebacks
        end
    end

    # @return   [Boolean]
    #   `true` if grid member, `false` otherwise.
    def grid_member?
        @peers.any?
    end

    def unplug
        @peers.each do |peer|
            connect_to_peer( peer ).remove_peer( @url ) {}
        end

        @peers.clear
        @dead_nodes.clear

        nil
    end

    # Adds a peer to the peer list.
    #
    # @param    [String]    node_url
    #   URL of a peering node.
    # @param    [Boolean]   propagate
    #   Whether or not to announce the new node to the peers.
    def add_peer( node_url, propagate = false )
        # we don't want ourselves in the Set
        return false if node_url == @url
        return false if @peers.include?( node_url )

        print_status "Adding peer: #{node_url}"

        @peers << node_url
        log_updated_peers
        announce( node_url ) if propagate

        connect_to_peer( node_url ).add_peer( @url, propagate ) do |res|
            next if !res.rpc_exception?
            add_dead_peer( node_url )
            print_status "Neighbour seems dead: #{node_url}"
        end
        true
    end

    def remove_peer( url )
        @peers.delete url
        @dead_nodes.delete url
        nil
    end

    # @return   [Array]
    #   Neighbour/node/peer URLs.
    def peers
        @peers.to_a
    end

    def peers_with_info( &block )
        fail 'This method requires a block!' if !block_given?

        @peers_cmp = ''

        if @nodes_info_cache.empty? || @peers_cmp != peers.to_s
            @peers_cmp = peers.to_s

            each = proc do |peer, iter|
                connect_to_peer( peer ).info do |info|
                    if info.rpc_exception?
                        print_info "Neighbour seems dead: #{peer}"
                        add_dead_peer( peer )
                        log_updated_peers

                        iter.return( nil )
                    else
                        iter.return( info )
                    end
                end
            end

            after = proc do |nodes|
                @nodes_info_cache = nodes.compact
                block.call( @nodes_info_cache )
            end

            Raktr.global.create_iterator( peers ).map( each, after )
        else
            block.call( @nodes_info_cache )
        end
    end

    # @return    [Hash]
    #
    #   * `url` -- This node's URL.
    #   * `name` -- Nickname
    #   * `peers` -- Array of peers.
    def info
        {
            'url'                    => @url,
            'name'                   => @options.agent.name,
            'peers'             => @peers.to_a,
            'unreachable_peers' => @dead_nodes.to_a
        }
    end

    def alive?
        true
    end

    private

    def add_dead_peer( url )
        remove_peer( url )
        @dead_nodes << url
    end

    def log_updated_peers
        print_info 'Updated peers:'

        if !peers.empty?
            peers.each { |node| print_info( '---- ' + node ) }
        else
            print_info '<empty>'
        end
    end

    def ping
        peers.each do |peer|
            connect_to_peer( peer ).alive? do |res|
                next if !res.rpc_exception?
                add_dead_peer( peer )
                print_status "Found dead peer: #{peer} "
            end
        end
    end

    def check_for_comebacks
        @dead_nodes.dup.each do |url|
            peer = connect_to_peer( url )
            peer.alive? do |res|
                next if res.rpc_exception?

                print_status "Agent came back to life: #{url}"
                ([@url] | peers).each do |node|
                    peer.add_peer( node ){}
                end

                add_peer( url )
                @dead_nodes.delete url
            end
        end
    end

    # Announces the node to the ones in the peer list
    #
    # @param    [String]    node
    #   URL
    def announce( node )
        print_status "Advertising: #{node}"

        peers.each do |peer|
            next if peer == node

            print_info '---- to: ' + peer
            connect_to_peer( peer ).add_peer( node ) do |res|
                add_dead_peer( peer ) if res.rpc_exception?
            end
        end
    end

    def connect_to_peer( url )
        @rpc_clients ||= {}
        @rpc_clients[url] ||= Client::Agent.new( url ).node
    end

end
end
end
