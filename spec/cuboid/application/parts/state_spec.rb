require 'spec_helper'

describe Cuboid::Application::Parts::State do
    include_examples 'application'

    describe '#running?' do
        it "delegates to #{Cuboid::State::Application}#scanning?" do
            allow(subject.state).to receive(:running?) { :stuff }
            expect(subject.running?).to eq(:stuff)
        end
    end

    describe '#done?' do
        it "delegates to #{Cuboid::State::Application}#done?" do
            allow(subject.state).to receive(:done?) { :stuff }
            expect(subject.done?).to eq(:stuff)
        end
    end

    describe '#paused?' do
        it "delegates to #{Cuboid::State::Application}#paused?" do
            allow(subject.state).to receive(:paused?) { :stuff }
            expect(subject.paused?).to eq(:stuff)
        end
    end

    describe '#state' do
        it "returns #{Cuboid::State::Application}" do
            expect(subject.state).to be_kind_of Cuboid::State::Application
        end
    end

    describe '#abort!' do
        it 'sets #status to :aborting' do
            MockApp.safe do |f|
                t = Thread.new do
                    f.run
                end

                sleep 1 while f.status == :ready

                f.abort!
                expect(f.status).to eq(:aborted)

                t.join
            end
        end
    end

    describe '#suspend!' do
        it 'suspends the system' do
            snapshot = nil
            MockApp.safe do |f|
                t = Thread.new do
                    f.run
                end

                sleep 1 while f.status != :running

                snapshot = f.suspend!
                expect(f.status).to eq(:suspended)

                t.join
            end

            expect(Cuboid::Snapshot.load( snapshot )).to be_truthy
        end

        context "when #{Cuboid::OptionGroups::Paths}#snapshots" do
            context 'is a directory' do
                it 'stores the snapshot under it' do
                    Cuboid::Options.snapshot.path = Dir.tmpdir

                    snapshot = nil
                    MockApp.safe do |f|
                        t = Thread.new do
                            f.run
                        end

                        sleep 0.1 while f.status != :running

                        snapshot = f.suspend!
                        t.join
                    end

                    expect(File.dirname( snapshot )).to eq(Dir.tmpdir)
                    expect(Cuboid::Snapshot.load( snapshot )).to be_truthy
                end
            end

            context 'is a file path' do
                it 'stores the snapshot there' do
                    Cuboid::Options.snapshot.path = "#{Dir.tmpdir}/snapshot"

                    snapshot = nil
                    MockApp.safe do |f|
                        t = Thread.new do
                            f.run
                        end

                        sleep 0.1 while f.status != :running

                        snapshot = f.suspend!
                        t.join
                    end

                    expect(snapshot).to eq("#{Dir.tmpdir}/snapshot")
                    expect(Cuboid::Snapshot.load( snapshot )).to be_truthy
                end
            end
        end
    end

    describe '#restore!' do
        it 'restores options' do
            options_hash = nil

            snapshot = nil
            MockApp.safe do |f|
                Cuboid::Options.datastore.my_custom_option = 'my custom value'

                t = Thread.new { f.run }
                sleep 0.1 while f.status != :running

                snapshot = f.suspend!

                t.join
            end

            MockApp.restore!( snapshot ) do |f|
                opts = Cuboid::Options.to_h
                expect(opts[:datastore][:my_custom_option]).to eq('my custom value')
            end
        end
    end

    describe '#pause!' do
        it 'pauses the system' do
            MockApp.safe do |f|
                t = Thread.new do
                    f.run
                end
                sleep 0.1 while f.status != :running

                f.pause!
                expect(f.status).to eq(:paused)
                expect(f.running?).to be_truthy

                f.resume!
                t.join
            end
        end
    end

    describe '#resume!' do
        it 'resumes the scan' do
            MockApp.safe do |f|
                t = Thread.new do
                    f.run
                end
                sleep( 1 ) while f.status == :ready

                f.pause!
                expect(f.status).to eq(:paused)

                f.resume!
                Timeout.timeout 5 do
                    sleep 0.1 while f.status != :done
                end

                t.join
            end
        end
    end

    describe '#clean_up' do
        it 'sets the status to cleanup' do
            MockApp.safe do |f|
                f.clean_up
                expect(f.status).to eq(:cleanup)
            end
        end

        it 'sets #running? to false' do
            MockApp.safe do |f|
                f.clean_up
                expect(f).not_to be_running
            end
        end
    end

end
