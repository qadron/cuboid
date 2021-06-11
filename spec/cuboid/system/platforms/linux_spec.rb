require 'spec_helper'

describe Cuboid::System::Platforms::Linux do
    it_should_behave_like 'Cuboid::System::Platforms::Mixins::Unix'

    describe '#memory_free' do
        it 'returns the amount of free memory' do
            o = Object.new
            expect(o).to receive(:available_bytes).and_return(1000)
            expect(subject).to receive(:memory).at_least(:once).and_return(o)

            expect(subject.memory_free).to eq 1000
        end
    end

    describe '.current?' do
        context 'when running on Linux' do
            it 'returns true' do
                expect(Cuboid).to receive(:linux?).and_return( true )
                expect(described_class).to be_current
            end
        end

        context 'when not running on Linux' do
            it 'returns false' do
                expect(Cuboid).to receive(:linux?).and_return( false )
                expect(described_class).to_not be_current
            end
        end
    end
end
