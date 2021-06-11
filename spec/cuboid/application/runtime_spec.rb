require 'spec_helper'

describe Cuboid::Application::Runtime do
    include_examples 'application'

    describe '#state' do
        it 'provides access to the application runtime state'
    end

    describe '#state=' do
        it 'sets the application runtime state'
    end

    describe '#data' do
        it 'provides access to the application runtime data'
    end

    describe '#data=' do
        it 'sets the application runtime data'
    end
end
