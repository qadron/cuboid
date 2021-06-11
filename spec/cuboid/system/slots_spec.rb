require 'spec_helper'

describe Cuboid::System::Slots do
    subject { system.slots }
    let(:system) { Cuboid::System.instance }

    before :each do
        subject.reset
    end

    describe '#available' do
        context 'when OptionGroups::system#max_slots is set' do
            before do
                Cuboid::Options.system.max_slots = 5
            end

            it 'uses it to calculate available slots' do
                expect(subject.available).to eq 5
            end

            context 'when some slots have been used' do
                it 'subtracts them' do
                    allow(subject).to receive(:used).and_return( 2 )
                    expect(subject.available).to eq 3
                end
            end
        end

        context 'when OptionGroups::system#max_slots is not set' do
            before do
                Cuboid::Options.system.max_slots = nil
            end

            it 'uses #available_auto' do
                expect(subject).to receive(:available_auto).and_return( 25 )
                expect(subject.available).to eq 25
            end
        end
    end

    describe '#available_auto' do
        before do
            Cuboid::Options.system.max_slots = nil
        end

        it 'calculates slots based on available resources' do
            expect(subject).to receive(:available_in_memory).and_return( 25 )
            expect(subject).to receive(:available_in_cpu).and_return( 25 )
            expect(subject).to receive(:available_in_disk).and_return( 25 )

            expect(subject.available).to eq 25
        end

        context 'when restricted by memory' do
            it 'bases the calculation on memory slots' do
                expect(subject).to receive(:available_in_memory).and_return( 10 )
                expect(subject).to receive(:available_in_cpu).and_return( 25 )
                expect(subject).to receive(:available_in_disk).and_return( 20 )

                expect(subject.available).to eq 10
            end
        end

        context 'when restricted by CPUs' do
            it 'bases the calculation on CPU slots' do
                expect(subject).to receive(:available_in_memory).and_return( 10 )
                expect(subject).to receive(:available_in_cpu).and_return( 5 )
                expect(subject).to receive(:available_in_disk).and_return( 20 )

                expect(subject.available).to eq 5
            end
        end

        context 'when restricted by disk space' do
            it 'bases the calculation on disk space' do
                expect(subject).to receive(:available_in_memory).and_return( 10 )
                expect(subject).to receive(:available_in_cpu).and_return( 5 )
                expect(subject).to receive(:available_in_disk).and_return( 4 )

                expect(subject.available).to eq 4
            end
        end
    end

    describe '#used' do
        it 'returns the amount of active instances' do
            expect(subject.used).to eq 0

            subject.use Process.pid
            expect(subject.used).to eq 1
        end

        context 'when a process dies' do
            it 'gets removed from the count'
        end
    end

    describe '#total' do
        it 'sums up free and used slots' do
            expect(subject).to receive(:available).and_return( 3 )
            expect(subject).to receive(:used).and_return( 5 )

            expect(subject.total).to eq 8
        end
    end

    describe '#available_in_memory' do
        it 'returns amount of free memory slots' do
            expect(subject).to receive(:unallocated_memory).and_return( subject.memory_size * 2 )

            expect(subject.available_in_memory).to eq 2
        end
    end

    describe '#available_in_cpu' do
        it 'returns amount of free CPUs splots' do
            expect(system).to receive(:cpu_count).and_return( 12 )
            expect(subject).to receive(:used).and_return( 5 )

            expect(subject.available_in_cpu).to eq 7
        end
    end

    describe '#unallocated_memory' do
        context 'when there are no scans running' do
            it 'returns the amount of free memory' do
                free = subject.memory_size * 2

                expect(system).to receive(:memory_free).and_return( free )

                expect(subject.unallocated_memory).to eq free
            end
        end

        context 'when there are scans running' do
            context 'using part of their allocation' do
                it 'removes their allocated slots' do
                    used_allocation = subject.memory_size / 3

                    expect(system).to receive(:memory_free).and_return( subject.memory_size * 2 - used_allocation )

                    subject.use 123
                    expect(subject).to receive(:remaining_memory_for).with(123).and_return( subject.memory_size - used_allocation )

                    expect(subject.unallocated_memory).to eq subject.memory_size
                end
            end
        end
    end

    describe '#remaining_memory_for' do
        it 'returns the amount of allocated memory available to the scan' do
            expect(system).to receive(:memory_for_process_group).with(123).and_return( subject.memory_size / 3 )
            expect(subject.remaining_memory_for(123)).to eq( subject.memory_size - subject.memory_size / 3 )
        end
    end

    describe '#unallocated_disk_space' do
        context 'when there are no scans running' do
            it 'returns the amount of free disk space' do
                free = subject.disk_space * 2

                expect(system).to receive(:disk_space_free).and_return( free )

                expect(subject.unallocated_disk_space).to eq free
            end
        end

        context 'when there are scans running' do
            context 'using part of their allocation' do
                it 'removes their allocated slots' do
                    used_allocation = subject.disk_space / 3

                    expect(system).to receive(:disk_space_free).and_return( subject.disk_space * 2 - used_allocation )

                    subject.use 123
                    expect(subject).to receive(:remaining_disk_space_for).with(123).and_return( subject.disk_space - used_allocation )

                    expect(subject.unallocated_disk_space.to_i).to eq subject.disk_space.to_i
                end
            end
        end
    end

    describe '#remaining_disk_space_for' do
        it 'returns the amount of allocated disk space available to the scan' do
            expect(system).to receive(:disk_space_for_process).with(123).and_return( subject.disk_space / 3 )
            expect(subject.remaining_disk_space_for(123)).to eq( subject.disk_space - subject.disk_space / 3 )
        end
    end

    describe '#memory_size' do
        before do
            Cuboid::Options.reset
        end
        let(:memory_size) { subject.memory_size }

        it 'is approx 0.2GB with default options' do
            expect(memory_size).to eq MockApp.max_memory
        end
    end
end
