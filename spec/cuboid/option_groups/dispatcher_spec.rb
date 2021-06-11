require 'spec_helper'

describe Cuboid::OptionGroups::Dispatcher do
    include_examples 'option_group'
    subject { described_class.new }

    %w(url instance_port_range neighbour ping_interval name).each do |method|
        it { is_expected.to respond_to method }
        it { is_expected.to respond_to "#{method}=" }
    end

end
