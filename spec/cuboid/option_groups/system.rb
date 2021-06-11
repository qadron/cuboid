require 'spec_helper'

describe Cuboid::OptionGroups::System do
    include_examples 'option_group'
    subject { described_class.new }

    %w(max_slots).each do |method|
        it { is_expected.to respond_to method }
        it { is_expected.to respond_to "#{method}=" }
    end

end
