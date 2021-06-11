require 'spec_helper'

describe Cuboid::Support::Database::Hash do

    before :each do
        subject.update seeds
    end

    subject { described_class.new }
    let(:non_existent) { 'blahblahblah' }
    let(:seeds) do
        {
            'key' => 'val',
            :key  => 'val2',
            { 'key' => 'val' } => 'val4'
        }
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-empty?
    it 'implements #empty?' do
        subject = described_class.new
        expect(subject.empty?).to eq({}.empty?)

        nh = { :k => 'v' }
        subject[:k] = 'v'

        expect(subject.empty?).to eq(nh.empty?)
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-5B-5D-3D
    it 'implements #[]=( k, v ) (and store( k, v ))' do
        seeds.each do |k, v|
            expect(subject[k] = v).to eq(v)
        end
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-5B-5D
    it 'implements #[]' do
        seeds.each do |k, v|
            expect(subject[k]).to eq(v)
        end

        expect(subject[non_existent]).to eq(seeds[non_existent])
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-assoc
    it 'implements #assoc( k )' do
        seeds.dup.each do |k, v|
            expect(subject.assoc( k )).to eq(seeds.assoc( k ))
        end

        expect(subject.assoc( non_existent )).to eq(seeds.assoc( non_existent ))
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-rassoc
    it 'implements #rassoc( k )' do
        seeds.each do |k, v|
            expect(subject.rassoc( v )).to eq(seeds.rassoc( v ))
        end

        expect(subject.rassoc( non_existent )).to eq(seeds.rassoc( non_existent ))
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-delete
    it 'implements #delete( k, &block )' do
        expect(subject.delete( non_existent )).to eq(seeds.delete( non_existent ))
        seeds[non_existent] = subject[non_existent] = 'foo'
        expect(subject.delete( non_existent )).to eq(seeds.delete( non_existent ))

        expect(subject.delete( non_existent ) { |k| k }).to eq(
            seeds.delete( non_existent ) { |k| k }
        )
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-shift
    it 'implements #shift' do
        expect(subject.shift).to eq(seeds.shift)
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-each
    it 'implements #each() (and #each_pair())' do
        subject.each do |k, v|
            expect(seeds[k]).to eq(v)
        end

        # they must both return enumerators
        expect(subject.each.class).to eq(seeds.each.class)

        subject.each_pair do |k, v|
            expect(seeds[k]).to eq(v)
        end

        # they must both return enumerators
        expect(subject.each_pair.class).to eq(seeds.each_pair.class)
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-each_key
    it 'implements #each_key' do
        subject.each_key do |k|
            expect(seeds[k]).to eq(subject[k])
        end

        # they must both return enumerators
        expect(subject.each_key.class).to eq(seeds.each_key.class)
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-each_value
    it 'implements #each_value' do
        subject.each_value do |v|
            expect(seeds[ seeds.key( v )]).to eq(v)
        end

        # they must both return enumerators
        expect(subject.each_value.class).to eq(seeds.each_value.class)
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-keys
    it 'implements #keys' do
        expect(subject.keys).to eq(seeds.keys)
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-key
    it 'implement #key' do
        subject.each_key do |k|
            expect(seeds.key( k )).to eq(subject.key( k ))
        end

        expect(subject.key( non_existent )).to eq(seeds.key( non_existent ))
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-values
    it 'implements #values' do
        expect(subject.values).to eq(seeds.values)
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-include?
    it 'implements #include? (and #member?, #key?, #has_key?)' do
        subject.each_key {
            |k|
            expect(seeds.include?( k )).to eq(subject.include?( k ))
            expect(seeds.member?( k )).to eq(subject.member?( k ))
            expect(seeds.key?( k )).to eq(subject.key?( k ))
            expect(seeds.has_key?( k )).to eq(subject.has_key?( k ))
        }

        expect(subject.include?( non_existent )).to eq(seeds.include?( non_existent ))
        expect(subject.member?( non_existent )).to eq(seeds.member?( non_existent ))
        expect(subject.key?( non_existent )).to eq(seeds.key?( non_existent ))
        expect(subject.has_key?( non_existent )).to eq(seeds.has_key?( non_existent ))
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-merge
    it 'implements #merge' do
        mh = { :another_key => 'another value' }

        nh = subject.merge( mh )
        expect(nh.keys).to eq(seeds.merge( mh ).keys)
        expect(nh.values).to eq(seeds.merge( mh ).values)
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-merge!
    it 'implements #merge! (and #update)' do
        mh = { :another_other_key => 'another other value' }
        mh2 = { :another_other_key2 => 'another other value2' }

        subject.merge!( mh )
        seeds.merge!( mh )

        subject.update( mh2 )
        seeds.update( mh2 )

        expect(subject.keys).to eq(seeds.keys)
        expect(subject.values).to eq(seeds.values)
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-to_hash
    it 'implements #to_hash' do
        expect(subject.to_hash).to eq(seeds.to_hash)
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-to_a
    it 'implements #to_a' do
        expect(subject.to_a).to eq(seeds.to_a)
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-size
    it 'implements #size' do
        expect(subject.size).to eq(seeds.size)
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-3D-3D
    it 'implements #== (and #eql?)' do
        expect(subject == subject.merge( {} )).to eq(true)
        expect(subject == seeds).to eq(true)
    end

    # http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-clear
    it 'implements #clear' do
        subject.clear
        seeds.clear
        expect(subject.size).to eq(seeds.size)
    end

end
