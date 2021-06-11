require 'spec_helper'

describe Cuboid::State::Options do

    subject { described_class.new }
    let(:dump_directory) do
        "#{Dir.tmpdir}/options-#{Cuboid::Utilities.generate_token}"
    end

    it { is_expected.to respond_to :clear}

    describe '#statistics' do
        let(:statistics) { subject.statistics }
    end

    describe '#dump' do
        it 'stores to disk' do
            Cuboid::Options.datastore.my_custom_option = 'my value'
            subject.dump( dump_directory )

            expect(Cuboid::Options.load( "#{dump_directory}/options" ).
                datastore.my_custom_option).to eq('my value')
        end
    end

    describe '.load' do
        it 'restores from disk' do
            Cuboid::Options.datastore.my_custom_option = 'my value'
            subject.dump( dump_directory )

            described_class.load( dump_directory )

            expect(Cuboid::Options.datastore.my_custom_option).to eq('my value')
        end
    end

end
