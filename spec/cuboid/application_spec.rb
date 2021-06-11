require 'spec_helper'

describe Cuboid::Application do
    include_examples 'application'

    describe '#version' do
        it "returns #{Cuboid::VERSION}" do
            expect(subject.version).to eq(Cuboid::VERSION)
        end
    end

    describe '#run' do
        context 'on invalid options' do
            it 'raises ArgumentError'
        end
    end

    describe '#statistics' do
        let(:statistics) { subject.statistics }

        describe ':runtime' do
            context 'when the app has been running' do
                it 'returns the runtime in seconds' do
                    subject.run
                    expect(statistics[:runtime]).to be > 0
                end
            end

            context 'when no scan has been running' do
                it 'returns 0' do
                    expect(statistics[:runtime]).to eq(0)
                end
            end
        end
    end

end
