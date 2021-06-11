require 'spec_helper'

describe Cuboid::Options do

    subject { described_class.instance }
    groups = described_class.group_classes.keys

    it 'proxies missing class methods to instance methods' do
        datastore = 'http://test.com/'
        expect(subject.datastore.url).not_to eq(datastore)
        subject.datastore.url = datastore
        expect(subject.datastore.url).to eq(datastore)
    end

    %w(authorized_by).each do |method|
        it { is_expected.to respond_to method }
        it { is_expected.to respond_to "#{method}=" }
    end

    groups.each do |group|
        describe "##{group}" do
            it 'is an OptionGroup' do
                expect(subject.send( group )).to be_kind_of Cuboid::OptionGroup
                expect(subject.send( group ).class.to_s.downcase).to eq(
                    "cuboid::optiongroups::#{group}".gsub( '_', '' )
                )
            end
        end
    end

    describe '#validate' do
        context 'when valid' do
            it 'returns nil' do
                expect(subject.validate).to be_empty
            end
        end

        context 'when invalid' do
            it 'returns errors by group'
        end
    end

    describe '#update' do
        it 'sets options by hash' do
            opts = { authorized_by: 'test@test.test' }

            subject.update( opts )
            expect(subject.authorized_by).to eq(opts[:authorized_by])
        end

        context 'when key refers to an OptionGroup' do
            it 'updates that group' do
                opts = {
                    datastore: {
                        key2: 'val2'
                    }
                }

                subject.update( opts )
                expect(subject.datastore.to_h).to eq(opts[:datastore])
            end
        end
    end

    describe '#save' do
        it 'dumps #to_h to a file' do
            f = 'options'

            subject.save( f )

            raised = false
            begin
                File.delete( f )
            rescue
                raised = true
            end
            expect(raised).to be_falsey
        end

        it 'returns the file location'do
            f = 'options'

            f = subject.save( f )

            raised = false
            begin
                File.delete( f )
            rescue
                raised = true
            end
            expect(raised).to be_falsey
        end
    end

    describe '#load' do
        it 'loads a file created by #save' do
            f = "#{Dir.tmpdir}/options"

            subject.datastore.stuff = 'test'
            subject.save( f )

            options = subject.load( f )
            expect(options).to eq(subject)
            expect(options.datastore.stuff).to eq('test')

            raised = false
            begin
                File.delete( f )
            rescue
                raised = true
            end
            expect(raised).to be_falsey
        end
    end

    describe '#to_rpc_data' do
        let(:data) { subject.to_rpc_data }

        it 'converts self to a serializable hash' do
            expect(data).to be_kind_of Hash

            expect(Cuboid::RPC::Serializer.load(
                Cuboid::RPC::Serializer.dump( data )
            )).to eq(data)
        end

        (groups - described_class::TO_RPC_IGNORE.to_a).each do |k|
            k = k.to_s

            it "includes the '#{k}' group" do
                expect(data[k]).to eq(subject.send(k).to_rpc_data)
            end
        end

        described_class::TO_RPC_IGNORE.each do |k|
            k = k.to_s

            it "does not include the '#{k}' group" do
                expect(subject.to_rpc_data).not_to include k
            end
        end
    end

    describe '#to_rpc_data_without_defaults' do
        before do
            Cuboid::Options.reset
        end

        it 'returns RPC data that are not identical to default settings' do
            expect(subject.dup.reset.to_rpc_data_without_defaults).to eq subject.to_rpc_data_without_defaults

            subject.authorized_by = 'test@test.test'
            subject.datastore.elements = 'forms'

            expect(subject.to_rpc_data_without_defaults).to eq({
                'authorized_by'   => 'test@test.test',
                'datastore' => {
                    'elements' => 'forms'
                }
            })
        end
    end

    describe '#to_hash' do
        let(:data) { subject.to_hash }

        it 'converts self to a hash' do
            subject.datastore.stuff = 'test2'

            h = subject.to_hash
            expect(h).to be_kind_of Hash
        end

        (groups - described_class::TO_HASH_IGNORE.to_a).each do |k|
            it "includes the '#{k}' group" do
                expect(data[k]).to eq(subject.send(k).to_hash)
            end
        end

        described_class::TO_HASH_IGNORE.each do |k|
            it "does not include the '#{k}' group" do
                expect(subject.to_hash).not_to include k
            end
        end

    end

    describe '#to_h' do
        it 'aliased to to_hash' do
            expect(subject.to_hash).to eq(subject.to_h)
        end
    end

    describe '#rpc_data_to_hash' do
        it 'normalizes the given hash into #to_hash format' do
            normalized = subject.rpc_data_to_hash(
                'datastore' => {
                    'request_timeout' => 90_000
                }
            )

            expect(normalized[:datastore][:request_timeout]).to eq(90_000)
            expect(subject.datastore.request_timeout).not_to eq(90_000)
        end
    end

    describe '#hash_to_rpc_data' do
        it 'normalizes the given hash into #to_rpc_data format' do
            normalized = subject.hash_to_rpc_data(
              datastore: { request_timeout: 90_000 }
            )

            expect(normalized['datastore']['request_timeout']).to eq(90_000)
            expect(subject.datastore.request_timeout).not_to eq(90_000)
        end
    end

end
