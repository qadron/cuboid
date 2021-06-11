require 'spec_helper'

describe Cuboid::Application::Parts::Data do
    include_examples 'application'

    describe '#data' do
        it "returns #{Cuboid::Data::Application}" do
            expect(subject.data).to be_kind_of Cuboid::Data::Application
        end
    end

end
