require 'spec_helper'

describe Cuboid::Data do

    subject { described_class }
    let(:dump_directory) do
        "#{Dir.tmpdir}/data-#{Cuboid::Utilities.generate_token}/"
    end

    describe '#application' do
        it "returns an instance of #{described_class::Application}" do
            expect(subject.application).to be_kind_of described_class::Application
        end
    end

    describe '#statistics' do
        %w(application).each do |name|
            it "includes :#{name} statistics" do
                expect(subject.statistics[name.to_sym]).to eq(subject.send(name).statistics)
            end
        end
    end

    describe '.dump' do
        %w(application).each do |name|
            it "stores ##{name} to disk" do
                previous_instance = subject.send(name)

                subject.dump( dump_directory )

                new_instance = subject.load( dump_directory ).send(name)

                expect(new_instance).to be_kind_of subject.send(name).class
                expect(new_instance.object_id).not_to eq(previous_instance.object_id)
            end
        end
    end

    describe '#clear' do
        %w(application).each do |method|
            it "clears ##{method}" do
                expect(subject.send(method)).to receive(:clear).at_least(:once)
                subject.clear
            end
        end
    end
end
