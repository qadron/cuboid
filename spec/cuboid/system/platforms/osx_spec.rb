require 'spec_helper'

describe Cuboid::System::Platforms::OSX do
    it_should_behave_like 'Cuboid::System::Platforms::Mixins::Unix'

    describe '#memory_free' do
        it 'returns the amount of free memory' do
            o = Object.new
            expect(o).to receive(:free).and_return(1000)
            expect(o).to receive(:pagesize).and_return(4096)
            expect(subject).to receive(:memory).at_least(:once).and_return(o)

            expect(subject.memory_free).to eq 4096000
        end
    end

    describe '.current?' do
        context 'when running on OSX' do
            it 'returns true' do
                expect(Cuboid).to receive(:mac?).and_return( true )
                expect(described_class).to be_current
            end
        end

        context 'when not running on OSX' do
            it 'returns false' do
                expect(Cuboid).to receive(:mac?).and_return( false )
                expect(described_class).to_not be_current
            end
        end
    end
end
