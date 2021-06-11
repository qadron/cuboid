require 'spec_helper'

describe Hash do
    let( :with_symbols ) do
        {
            stuff: 'blah',
            more: {
                stuff: {
                    blah: 'stuff'
                }
            }
        }
    end

    let( :with_strings ) do
        {
            'stuff' => 'blah',
            'more'  => {
                'stuff' => {
                    'blah' => 'stuff'
                }
            }
        }
    end

    describe '#my_stringify_keys' do
        it 'recursively converts keys to strings' do
            expect(with_symbols.my_stringify_keys).to eq(with_strings)
        end

        context 'when the recursive is set to false' do
            it 'only converts the keys at depth 1' do
                expect(with_symbols.my_stringify_keys( false )).to eq({
                    'stuff' => 'blah',
                    'more'  => {
                        stuff: {
                            blah: 'stuff'
                        }
                    }
                })
            end
        end
    end

    describe '#my_symbolize_keys' do
        it 'recursively converts keys to symbols' do
            expect(with_strings.my_symbolize_keys).to eq(with_symbols)
        end

        context 'when the recursive is set to false' do
            it 'only converts the keys at depth 1' do
                expect(with_strings.my_symbolize_keys( false )).to eq({
                    stuff: 'blah',
                    more:  {
                        'stuff' => {
                            'blah' => 'stuff'
                        }
                    }
                })
            end
        end
    end
end
