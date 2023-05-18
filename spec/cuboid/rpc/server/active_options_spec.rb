require 'spec_helper'

require Cuboid::Options.paths.lib + 'rpc/client/instance'
require Cuboid::Options.paths.lib + 'rpc/server/instance'

describe Cuboid::RPC::Server::ActiveOptions do
    let(:instance) { instance_spawn application: "#{fixtures_path}/mock_app.rb", daemonize: true }

    describe '#set' do
        it 'sets options by hash' do
            opts = {
                'datastore' => { 'key' => 'val' },
            }

            instance.options.set( opts )
            h = instance.options.to_h

            expect(h['datastore']['key']).to eq(opts['datastore']['key'])
        end
    end
end
