require 'spec_helper'

describe Cuboid::Data::Application do

    subject { described_class.new }
    let(:dump_directory) do
        "#{Dir.tmpdir}/framework-#{Cuboid::Utilities.generate_token}"
    end

    describe '#statistics' do
        let(:statistics) { subject.statistics }
    end

    describe '#dump' do
    end

    describe '.load' do
    end

    describe '#clear' do
    end
end
