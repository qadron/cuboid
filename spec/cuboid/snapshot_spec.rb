require 'spec_helper'

describe Cuboid::Snapshot do

    subject { described_class }
    let(:dump_archive) do
        "#{Cuboid::Options.paths.tmpdir}/snapshot-#{Cuboid::Utilities.generate_token}.#{described_class::EXTENSION}"
    end

    describe '.summary' do
        let(:summary) { subject.summary }

        it 'includes :data' do
            expect(summary[:data]).to eq(Cuboid::Data.statistics)
        end

        it 'includes :state' do
            expect(summary[:state]).to eq(Cuboid::State.statistics)
        end
    end

    describe '.metadata' do
        context 'when dealing with a restored snapshot' do
            it 'returns the stored metadata from the snapshot archive' do
                subject.dump( dump_archive )
                subject.load( dump_archive )

                expect(subject.metadata).to eq(subject.read_metadata( dump_archive ))
            end
        end

        context 'when not dealing with a restored snapshot' do
            it 'returns nil' do
                expect(subject.metadata).to be_nil
            end
        end
    end

    describe '.restored?' do
        context 'when dealing with a restored snapshot' do
            it 'returns true' do
                subject.dump( dump_archive )
                subject.load( dump_archive )

                expect(subject).to be_restored
            end
        end

        context 'when not dealing with a restored snapshot' do
            it 'returns false' do
                expect(subject).not_to be_restored
            end
        end
    end

    describe '.location' do
        context 'when dealing with a restored snapshot' do
            it 'returns the location of the loaded snapshot' do
                subject.dump( dump_archive )
                subject.load( dump_archive )

                expect(subject.location).to eq(dump_archive)
            end
        end

        context 'when not dealing with a restored snapshot' do
            it 'returns nil' do
                expect(subject.location).to be_nil
            end
        end
    end

    describe '.read_metadata' do
        let(:metadata) do
            subject.dump( dump_archive )
            subject.read_metadata( dump_archive )
        end

        it 'includes a :timestamp' do
            expect(metadata[:timestamp]).to be_kind_of Time
        end

        it 'includes a :version' do
            expect(metadata[:version]).to eq(Cuboid::VERSION)
        end

        it 'includes a #summary' do
            expect(metadata[:summary]).to eq(subject.summary)
        end

        context 'when trying to read an invalid file' do
            it "raises #{described_class::Error::InvalidFile}" do
                expect { subject.read_metadata( __FILE__ ) }.to raise_error described_class::Error::InvalidFile
            end
        end
    end

    describe '.dump' do
        it "stores #{Cuboid::State} to disk" do
            expect(Cuboid::State).to receive(:dump)
            expect(Cuboid::Data).to receive(:dump)

            subject.dump( dump_archive )
        end
    end

    describe '.load' do
        it "stores #{Cuboid::State} to disk" do
            subject.dump( dump_archive )

            expect(Cuboid::State).to receive(:load)
            expect(Cuboid::Data).to receive(:load)

            subject.load( dump_archive )
        end

        context 'when trying to load an invalid file' do
            it "raises #{described_class::Error::InvalidFile}" do
                expect { subject.load( __FILE__ ) }.to raise_error described_class::Error::InvalidFile
            end
        end
    end
end
