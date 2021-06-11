require 'spec_helper'

describe Array do
    subject do
        arr = described_class.new
        50.times { |i| arr << i }
        arr
    end

    describe '#includes_tag?' do
        context 'when passed' do
            context 'nil' do
                it 'returns false' do
                    expect(subject.includes_tags?( nil )).to eq(false)
                end
            end

            context '[]' do
                it 'returns false' do
                    expect(subject.includes_tags?( [] )).to eq(false)
                end
            end

            context 'String' do
                context 'when includes the given tag (as either a String or a Symbol)' do
                    it 'returns true' do
                        expect([ 1 ].includes_tags?( 1 )).to eq(true)
                        expect([ :tag ].includes_tags?( :tag )).to eq(true)
                        expect([ :tag ].includes_tags?( 'tag' )).to eq(true)
                        expect(%w(tag).includes_tags?( 'tag' )).to eq(true)
                        expect(%w(tag).includes_tags?( :tag )).to eq(true)
                        expect([ :tag, 'tag' ].includes_tags?( :tag )).to eq(true)
                        expect([ :tag, 'tag' ].includes_tags?( 'tag' )).to eq(true)
                    end
                end
                context 'when it does not includes the given tag (as either a String or a Symbol)' do
                    it 'returns false' do
                        expect([ 1 ].includes_tags?( 2 )).to eq(false)
                        expect([ :tag ].includes_tags?( :tag1 )).to eq(false)
                        expect([ :tag ].includes_tags?( 'tag2' )).to eq(false)
                        expect(%w(tag).includes_tags?( 'tag3' )).to eq(false)
                        expect(%w(tag).includes_tags?( :tag5 )).to eq(false)
                        expect([ :tag, 'tag' ].includes_tags?( :ta5g )).to eq(false)
                        expect([ :tag, 'tag' ].includes_tags?( 'ta4g' )).to eq(false)
                        expect([ :t3ag, 'tag1' ].includes_tags?( 'tag' )).to eq(false)
                    end
                end
            end

            context 'Array' do
                context 'when includes any of the given tags (as either a String or a Symbol)' do
                    it 'returns true' do
                        expect([ 1, 2, 3 ].includes_tags?( [1] )).to eq(true)
                        expect([ :tag ].includes_tags?( [:tag] )).to eq(true)
                        expect([ :tag ].includes_tags?( ['tag', 12] )).to eq(true)
                        expect(%w(tag).includes_tags?( ['tag', nil] )).to eq(true)
                        expect(%w(tag).includes_tags?( [:tag] )).to eq(true)
                        expect([ :tag, 'tag' ].includes_tags?( [:tag] )).to eq(true)
                        expect([ :tag, 'tag' ].includes_tags?( ['tag', :blah] )).to eq(true)
                    end
                end
                context 'when it does not include any of the given tags (as either a String or a Symbol)' do
                    it 'returns true' do
                        expect([ 1, 2, 3 ].includes_tags?( [4, 5] )).to eq(false)
                        expect([ :tag ].includes_tags?( [:ta3g] )).to eq(false)
                        expect([ :tag ].includes_tags?( ['ta3g', 12] )).to eq(false)
                        expect(%w(tag).includes_tags?( ['ta3g', nil] )).to eq(false)
                        expect(%w(tag).includes_tags?( [:t4ag] )).to eq(false)
                        expect([ :tag, 'tag' ].includes_tags?( [:t3ag] )).to eq(false)
                        expect([ :tag, 'tag' ].includes_tags?( ['t2ag', :b3lah] )).to eq(false)
                    end
                end
            end
        end
    end

end
