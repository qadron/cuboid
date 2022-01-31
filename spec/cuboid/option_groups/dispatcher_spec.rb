require 'spec_helper'

describe Cuboid::OptionGroups::Agent do
    include_examples 'option_group'
    subject { described_class.new }

    %w(url instance_port_range peer ping_interval name).each do |method|
        it { is_expected.to respond_to method }
        it { is_expected.to respond_to "#{method}=" }
    end

end
