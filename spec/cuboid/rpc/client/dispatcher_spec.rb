require 'spec_helper'
require 'fileutils'

describe Cuboid::RPC::Client::Agent do
    subject { agent_spawn application: "#{fixtures_path}/mock_app.rb" }

    describe '#node' do
        it 'provides access to the node data' do
            expect(subject.node.info.is_a?( Hash )).to be_truthy
        end
    end

end
