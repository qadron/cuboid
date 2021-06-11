shared_examples_for 'Cuboid::System::Platforms::Mixins::Unix' do
    it_should_behave_like 'Cuboid::System::Platforms::Base'

    subject { described_class.new }

    describe '#memory_for_process_group' do
        let(:ps) do
            <<EOTXT
   RSS
109744
 63732
 62236
 63876
 62772
 62856
 64504
EOTXT
        end

        it 'returns bytes of memory used by the group' do
            expect(subject).to receive(:pagesize).and_return(4096)
            expect(subject).to receive(:_exec).with('ps -o rss -g 123').and_return(ps)
            expect(subject.memory_for_process_group( 123 )).to eq 2005893120
        end
    end

    describe '#disk_space_free' do
        it 'returns the amount of free disk space' do
            o = Object.new
            expect(o).to receive(:available_bytes).and_return(1000)
            expect(Vmstat).to receive(:disk).with(Cuboid::Options.paths.os_tmpdir).and_return(o)

            expect(subject.disk_space_free).to eq 1000
        end
    end

end
