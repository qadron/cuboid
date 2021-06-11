require 'spec_helper'

describe Cuboid::Support::Filter::Set do
    it_behaves_like 'filter'

    describe '#merge' do
        it 'merges 2 sets' do
            new = described_class.new

            subject << 'test'
            new     << 'test2'

            subject.merge new
            expect(subject).to include 'test'
            expect(subject).to include 'test2'
        end
    end

end
