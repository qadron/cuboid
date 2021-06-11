require 'spec_helper'

describe Cuboid::OptionGroups::Paths do

    before :all do
        @created_resources = []
    end

    after :each do
        ENV['CUBOID_LOGDIR'] = nil

        (@created_resources + [paths_config_file]).each do |r|
            FileUtils.rm_rf r
        end
    end

    let(:paths_config_file) { "#{Cuboid::Options.paths.tmpdir}/paths-#{Process.pid}.yml" }

    %w(root logs reports lib support mixins snapshots).each do |method|

        describe "##{method}" do
            it 'points to an existing directory' do
                expect(File.exists?( subject.send method )).to be_truthy
            end
        end

        describe "##{method}=" do
            context 'when the path is missing a slash in the end' do
                it 'raises error' do
                    dir = subject.tmpdir[0..-1]
                    subject.send "#{method}=", dir

                    expect(dir).to_not end_with '/'
                    expect(subject.send(method)).to end_with '/'
                end
            end

            context 'when given an invalid directory' do
                it 'raises error' do
                    expect do
                        subject.send "#{method}=", 'flflflfl'
                    end.to raise_error ArgumentError
                end
            end
        end

        it { is_expected.to respond_to method }
        it { is_expected.to respond_to "#{method}=" }
    end

    describe '#tmpdir' do
        context 'when no tmpdir has been specified via config' do
            it 'defaults to the OS tmpdir' do
                expect(subject.tmpdir).to eq Cuboid.get_long_win32_filename( "#{Dir.tmpdir}/Cuboid_#{Process.pid}" )
            end
        end

        context "when #{described_class}.config['tmpdir']" do
            it 'returns its value' do
                allow(described_class).to receive(:config) do
                    {
                        'tmpdir' => "#{Dir.tmpdir}/my/tmpdir"
                    }
                end

                expect(subject.tmpdir).to eq("#{Dir.tmpdir}/my/tmpdir/Cuboid_#{Process.pid}")
            end
        end
    end

    describe '#logs' do
        it 'returns the default location' do
            expect(subject.logs).to eq("#{subject.root}logs/")
        end

        context 'when the CUBOID_LOGDIR environment variable' do
            after { ENV['CUBOID_LOGDIR'] = '' }

            it 'returns its value' do
                ENV['CUBOID_LOGDIR'] = 'test'
                expect(subject.logs).to eq('test/')
            end
        end

        context "when #{described_class}.config['logs']" do
            it 'returns its value' do
                allow(described_class).to receive(:config) do
                    {
                        'logs' => 'logs-stuff/'
                    }
                end

                expect(described_class.new.logs).to eq('logs-stuff/')
            end
        end
    end

    describe '#snapshots' do
        it 'returns the default location' do
            expect(subject.snapshots).to eq("#{subject.root}snapshots/")
        end

        context "when #{described_class}.config['snapshots']" do
            it 'returns its value' do
                allow(described_class).to receive(:config) do
                    {
                        'snapshots' => 'snapshots-stuff/'
                    }
                end

                expect(described_class.new.snapshots).to eq('snapshots-stuff/')
            end
        end
    end

    describe '#reports' do
        it 'returns the default location' do
            expect(subject.reports).to eq("#{subject.root}reports/")
        end

        context "when #{described_class}.config['reports']" do
            it 'returns its value' do
                allow(described_class).to receive(:config) do
                    {
                        'reports' => 'reports-stuff/'
                    }
                end

                expect(described_class.new.reports).to eq('reports-stuff/')
            end
        end
    end

    describe '.config' do
        let(:config) { described_class.config }

        it 'expands ~ to $HOME', if: !Cuboid.windows? do
            yaml = {
                'blah' => "~/foo-#{Process.pid}/"
            }.to_yaml

            allow(described_class).to receive(:paths_config_file) { paths_config_file }
            IO.write( described_class.paths_config_file, yaml )
            described_class.clear_config_cache

            @created_resources << described_class.config['blah']

            expect(described_class.config['blah']).to eq("#{ENV['HOME']}/foo-#{Process.pid}/")
        end

        it 'appends / to paths' do
            dir = "#{Dir.tmpdir}/foo-#{Process.pid}"
            yaml = {
                'blah' => dir
            }.to_yaml

            allow(described_class).to receive(:paths_config_file) { paths_config_file }
            IO.write( described_class.paths_config_file, yaml )
            described_class.clear_config_cache

            @created_resources << described_class.config['blah']

            expect(described_class.config['blah']).to eq("#{dir}/")
        end

        it 'creates the given directories' do
            dir = "#{Dir.tmpdir}/foo/stuff-#{Process.pid}"
            yaml = {
                'blah' => dir
            }.to_yaml

            allow(described_class).to receive(:paths_config_file) { paths_config_file }
            IO.write( described_class.paths_config_file, yaml )
            described_class.clear_config_cache

            @created_resources << dir

            expect(File.exist?( dir )).to be_falsey
            described_class.config
            expect(File.exist?( dir )).to be_truthy
        end
    end

end
