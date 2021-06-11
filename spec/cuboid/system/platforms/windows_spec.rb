require 'spec_helper'

describe Cuboid::System::Platforms::Windows, if: Cuboid.windows? do
    it_should_behave_like 'Cuboid::System::Platforms::Base'

    subject { described_class.new }

    describe '#memory_free' do
        it 'returns the amount of free memory' do
            expect(subject.memory_free).to be > 0
        end
    end

    describe '#disk_space_free' do
        it 'returns the amount of free disk space' do
            expect(subject.disk_space_free).to be > 0
        end
    end

    describe '#memory_for_process_group' do
        it 'returns bytes of memory used by the group' do
            expect(subject.memory_for_process_group( Process.pid )).to be > 0
        end
    end

    describe '.current?' do
        context 'when running on Windows' do
            it 'returns true'do
                expect(Cuboid).to receive(:windows?).and_return( true )
                expect(described_class).to be_current
            end
        end

        context 'when not running on Windows' do
            it 'returns false' do
                expect(Cuboid).to receive(:windows?).and_return( false )
                expect(described_class).to_not be_current
            end
        end
    end
end
