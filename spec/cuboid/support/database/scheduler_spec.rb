require 'spec_helper'

describe Cuboid::Support::Database::Queue do

    subject { described_class.new }
    let(:sample_size) { 2 * subject.max_buffer_size }

    it 'maintains stability and consistency under load' do
        subject

        entries = 1000
        poped   = Queue.new
        t       = []

        10.times do
            t << Thread.new do
                loop do
                    poped << subject.pop
                end
            end
        end

        entries.times do |i|
            subject << 'a' * i
        end

        sleep 0.1 while !subject.empty?

        consumed = []
        consumed << poped.pop while !poped.empty?

        expect(consumed.sort).to eq((0...entries).map { |i| 'a' * i })
    end

    describe "#{described_class}::DEFAULT_MAX_BUFFER_SIZE" do
        it 'returns 100' do
            expect(described_class::DEFAULT_MAX_BUFFER_SIZE).to eq(100)
        end
    end

    describe '#initialize' do
        describe ':max_buffer_size' do
            it 'sets #max_buffer_size' do
                expect(
                    described_class.new( max_buffer_size: 1 ).max_buffer_size
                ).to eq 1
            end
        end

        describe ':dumper' do
            it 'defaults to Marshal' do
                d = described_class.new( max_buffer_size: 0 )
                d << 1

                expect(d.unserialize(IO.binread(d.disk.first))).to eq 1
            end

            context 'it responds to :dump' do
                it 'gets called to serialize the object' do
                    class Dumper; def self.dump(o) o.to_s << '-' end ;end

                    d = described_class.new(
                        max_buffer_size: 0,
                        dumper: Dumper
                    )
                    d << 1

                    expect(Zlib::Inflate.inflate IO.binread(d.disk.first)).to eq '1-'
                end
            end

            context 'it responds to :call' do
                it 'gets called to serialize the object' do
                    d = described_class.new(
                        max_buffer_size: 0,
                        dumper: proc do |o|
                            o.to_s << '-'
                        end
                    )
                    d << 1

                    expect(Zlib::Inflate.inflate IO.binread(d.disk.first)).to eq '1-'
                end
            end
        end

        describe ':load' do
            context 'it responds to :load' do
                it 'gets called to unserialize the object' do
                    class Loader; def self.load(o) o + '-' end ;end

                    d = described_class.new(
                        max_buffer_size: 0,
                        loader: Loader
                    )
                    d << 1

                    expect(d.pop).to eq Marshal.dump( 1 ) + '-'
                end
            end

            context 'it responds to :call' do
                it 'gets called to serialize the object' do
                    d = described_class.new(
                        max_buffer_size: 0,
                        loader: proc do |o|
                            o + '-'
                        end
                    )
                    d << 1

                    expect(d.pop).to eq Marshal.dump( 1 ) + '-'
                end
            end
        end
    end

    describe '#buffer' do
        it 'returns the objects stored in the memory buffer' do
            subject << 1
            subject << 2

            expect(subject.buffer).to eq([1, 2])
        end
    end

    describe '#disk' do
        it 'returns paths to the files of objects stored to disk' do
            subject.max_buffer_size = 0
            subject << 1
            subject << 2

            expect(subject.disk.size).to eq(2)
            subject.disk.each do |path|
                expect(File.exist?( path )).to be_truthy
            end
        end
    end

    describe '#max_buffer_size' do
        context 'by default' do
            it "returns #{described_class}::DEFAULT_MAX_BUFFER_SIZE" do
                expect(subject.max_buffer_size).to eq(described_class::DEFAULT_MAX_BUFFER_SIZE)
            end
        end
    end

    describe '#max_buffer_size=' do
        it 'sets #max_buffer_size' do
            subject.max_buffer_size = 10
            expect(subject.max_buffer_size).to eq(10)
        end
    end

    describe '#empty?' do
        context 'when the queue is empty' do
            it 'returns true' do
                expect(subject.empty?).to be_truthy
            end
        end

        context 'when the queue is not empty' do
            it 'returns false' do
                subject << :stuff
                expect(subject.empty?).to be_falsey
            end
        end
    end

    describe '#<<' do
        it 'pushes an object' do
            sample_size.times do |i|
                subject << "stuff #{i}"
            end

            sample_size.times do |i|
                expect(subject.pop).to eq("stuff #{i}")
            end
        end
    end

    describe '#push' do
        it 'pushes an object' do
            subject.push :stuff
            expect(subject.pop).to eq(:stuff)
        end

        it 'increments .disk_space' do
            sz = described_class.disk_space

            subject.max_buffer_size = 0
            subject.push 'a' * 100

            expect(described_class.disk_space).to be > sz
        end
    end

    describe '#enq' do
        it 'pushes an object' do
            subject.enq :stuff
            expect(subject.pop).to eq(:stuff)
        end
    end

    describe '#pop' do
        it 'removes an object' do
            sample_size.times do |i|
                subject << "stuff #{i}"
            end

            sample_size.times do |i|
                expect(subject.pop).to eq("stuff #{i}")
            end
        end

        it 'blocks until an entry is available' do
            val = nil

            t = Thread.new { val = subject.pop }
            sleep 1
            Thread.new { subject << :stuff }
            t.join

            expect(val).to eq(:stuff)
        end

        it 'decrements .disk_space' do
            subject.max_buffer_size = 0
            subject.push 'a' * 100

            sz = described_class.disk_space
            subject.pop

            expect(described_class.disk_space).to be < sz
        end
    end

    describe '#deq' do
        it 'removes an object' do
            subject << :stuff
            expect(subject.deq).to eq(:stuff)
        end
    end

    describe '#shift' do
        it 'removes an object' do
            subject << :stuff
            expect(subject.shift).to eq(:stuff)
        end
    end

    describe '#size' do
        it 'returns the size of the queue' do
            sample_size.times { |i| subject << i }
            expect(subject.size).to eq(sample_size)
        end
    end

    describe '#free_buffer_size' do
        it 'returns the size of the available buffer' do
            (subject.max_buffer_size - 2).times { |i| subject << i }
            expect(subject.free_buffer_size).to eq(2)
        end
    end

    describe '#buffer_size' do
        it 'returns the size of the in-memory entries' do
            expect(subject.buffer_size).to eq(0)

            (subject.max_buffer_size - 1).times { |i| subject << i }
            expect(subject.buffer_size).to eq(subject.max_buffer_size - 1)

            subject.clear

            sample_size.times { |i| subject << i }
            expect(subject.buffer_size).to eq(subject.max_buffer_size)
        end
    end

    describe '#disk_size' do
        it 'returns the size of the disk entries' do
            expect(subject.buffer_size).to eq(0)

            (subject.max_buffer_size + 1).times { |i| subject << i }
            expect(subject.disk_size).to eq(1)

            subject.clear

            sample_size.times { |i| subject << i }
            expect(subject.disk_size).to eq(sample_size - subject.max_buffer_size)
        end
    end

    describe '#num_waiting' do
        it 'returns the amount of threads waiting to pop' do
            expect(subject.num_waiting).to eq(0)

            2.times do
                Thread.new { subject.pop }
            end
            sleep 0.1

            expect(subject.num_waiting).to eq(2)
        end
    end

    describe '#clear' do
        it 'empties the queue' do
            sample_size.times { |i| subject << i }
            subject.clear
            expect(subject.size).to eq(0)
        end

        it 'decrements .disk_space' do
            subject.max_buffer_size = 0
            subject.push 'a' * 100

            sz = described_class.disk_space
            subject.clear

            expect(described_class.disk_space).to be < sz
        end
    end

end
