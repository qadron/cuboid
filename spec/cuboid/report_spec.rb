require 'spec_helper'

describe Cuboid::Report do

    after :each do
        File.delete( @report_file ) rescue nil
    end

    let( :report_data ) { Factory[:report_data] }
    let( :report ) { Factory[:report] }
    let( :report_empty ) { Factory[:report_empty] }

    it "supports #{Cuboid::RPC::Serializer}" do
        cloned = Cuboid::RPC::Serializer.deep_clone( report )
        cloned.options.delete :input

        expect(report).to eq(cloned)
    end

    describe '#to_rpc_data' do
        let(:subject) { report }
        let(:data) { subject.to_rpc_data }

        %w(seed version).each do |attribute|
            it "includes '#{attribute}'" do
                expect(data[attribute]).to eq(subject.send( attribute ))
            end
        end

        it "includes serialized 'data'" do
            expect(data['data']).to eq Cuboid::Application.application.serializer.dump(subject.data)
        end

        it "includes 'options'" do
            expect(data['options']).to eq(
                Cuboid::Application.application.serializer.dump subject.options
            )
        end

        %w(start_datetime finish_datetime).each do |attribute|
            it "includes '#{attribute}'" do
                expect(data[attribute]).to eq(subject.send( attribute ).to_s)
            end
        end
    end

    describe '.from_rpc_data' do
        let(:subject) { report }

        let(:restored) { described_class.from_rpc_data data }
        let(:data) { Cuboid::RPC::Serializer.rpc_data( subject ) }

        %w(seed version data).each do |attribute|
            it "restores '#{attribute}'" do
                expect(restored.send( attribute )).to eq(subject.send( attribute ))
            end
        end

        it "restores 'options'" do
            restored.options.delete :input
            subject.options.delete :input

            expect(restored.options).to eq(subject.options)
        end

        %w(start_datetime finish_datetime).each do |attribute|
            it "restores '#{attribute}'" do
                expect(restored.send( attribute )).to be_kind_of Time
                expect(restored.send( attribute ).to_s).to eq(subject.send( attribute ).to_s)
            end
        end
    end

    describe '#version' do
        it 'returns the version number' do
            expect(report.version).to eq(Cuboid::VERSION)
        end
    end

    describe '#seed' do
        it 'returns the scan seed' do
            expect(report.seed).to eq(Cuboid::Utilities.random_seed)
        end
    end

    describe '#options' do
        it 'returns application options'
    end

    describe '#start_datetime' do
        it 'returns a Time object' do
            expect(report.start_datetime).to be_kind_of Time
        end
        context 'when no start datetime info has been provided' do
            it 'falls-back to Time.now' do
                expect(report_empty.start_datetime).to be_kind_of Time
            end
        end
    end

    describe '#finish_datetime' do
        it 'returns a Time object' do
            expect(report.finish_datetime).to be_kind_of Time
        end
        it 'returns the start finish of the scan' do
            expect(report.finish_datetime.to_s).to eq(
                Factory[:report_data][:finish_datetime].to_s
            )
        end
        context 'when no start datetime info has been provided' do
            it 'falls-back to Time.now' do
                expect(report_empty.finish_datetime).to be_kind_of Time
            end
        end
    end

    describe '#delta_time' do
        it 'returns the time difference between start and finish time' do
            expect(report.delta_time).to eq('02:46:40')
        end
        context 'when no #finish_datetime has been provided' do
            it 'uses Time.now for the calculation' do
                report_empty.start_datetime = Time.now - 2000
                expect(report_empty.delta_time.to_s).to eq('00:33:19')
            end
        end
    end

    describe '.read_summary' do
        it 'returns summary' do
            summary = report.summary
            summary[:application] = summary[:application].to_s

            @report_file = report.save
            expect(described_class.read_summary( @report_file )).to eq(
                Cuboid::RPC::Serializer.load( Cuboid::RPC::Serializer.dump( summary ) ).
                  my_symbolize_keys.tap do |s|
                    s[:application] = ObjectSpace.const_get( s[:application].to_sym )
                end
            )
        end
    end

    describe '#save' do
        it 'dumps the object to a file' do
            @report_file = report.save

            expect(described_class.load( @report_file )).to eq(report)
        end

        context 'when given a location' do
            context 'which is a filepath' do
                it 'saves the object to that file' do
                    @report_file = 'report'
                    report.save( @report_file )

                    expect(described_class.load( @report_file )).to eq(report)
                end
            end

            context 'which is a directory' do
                it 'saves the object under that directory' do
                    directory = Dir.tmpdir
                    @report_file = report.save( directory )

                    expect(described_class.load( @report_file )).to eq(report)
                end
            end
        end
    end

    describe '#to_crf' do
        it 'returns the object in CRF format' do
            @report_file = report.save

            expect(IO.binread( @report_file )).to eq(report.to_crf)
        end
    end

    describe '#from_crf' do
        it 'loads an object from CRF data'
    end

    describe '#to_h' do
        it 'returns the object as a hash' do
            expect(report.to_h).to eq({
                application:     MockApp,
                version:         report.version,
                status:          report.status,
                data:            report.data,
                seed:            report.seed,
                options:         Cuboid::Options.hash_to_rpc_data( report.options ),
                start_datetime:  report.start_datetime.to_s,
                finish_datetime: report.finish_datetime.to_s,
                delta_time:      report.delta_time,
            })
        end
    end

    describe '#to_hash' do
        it 'alias of #to_h' do
            expect(report.to_h).to eq(report.to_hash)
        end
    end

    describe '#==' do
        context 'when the reports are equal' do
            it 'returns true' do
                expect(described_class.from_crf( report.to_crf )).to eq(report)
            end
        end
        context 'when the reports are not equal' do
            it 'returns false' do
                a = described_class.from_crf( report.to_crf )
                a.options[:authorized_by] = 'http://stuff/'
                expect(a).not_to eq(report)
            end
        end
    end

end
