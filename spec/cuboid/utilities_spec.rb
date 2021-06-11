require 'spec_helper'

class Subject
    include Cuboid::UI::Output
    include Cuboid::Utilities
end

describe Cuboid::Utilities do

    subject { Subject.new }

    let(:response) { Factory[:response] }
    let(:page) { Factory[:page] }

    describe '#caller_name' do
        it 'returns the filename of the caller' do
            expect(subject.caller_name).to eq('example')
        end
    end

    describe '#caller_path' do
        it 'returns the filepath of the caller' do
            expect(subject.caller_path).to eq(Kernel.caller.first.match( /^(.+):\d/ )[1])
        end
    end

    describe '#port_available?' do
        context 'when a port is available' do
            it 'returns true' do
                expect(subject.port_available?( 7777 )).to be_truthy
            end
        end

        context 'when a port is not available' do
            it 'returns true' do
                s = TCPServer.new( "127.0.0.1", 7777 )
                expect(subject.port_available?( 7777 )).to be_falsey
                s.close
            end
        end
    end

    describe '#random_seed' do
        it 'returns a random string' do
            expect(subject.random_seed).to be_kind_of String
        end
    end

    describe '#seconds_to_hms' do
        it 'converts seconds to HOURS:MINUTES:SECONDS' do
            expect(subject.seconds_to_hms( 0 )).to eq('00:00:00')
            expect(subject.seconds_to_hms( 1 )).to eq('00:00:01')
            expect(subject.seconds_to_hms( 60 )).to eq('00:01:00')
            expect(subject.seconds_to_hms( 60*60 )).to eq('01:00:00')
            expect(subject.seconds_to_hms( 60*60 + 60 + 1 )).to eq('01:01:01')
        end
    end

    describe '#hms_to_seconds' do
        it 'converts seconds to HOURS:MINUTES:SECONDS' do
            expect(subject.hms_to_seconds( '00:00:00' )).to eq(0)
            expect(subject.hms_to_seconds( '00:00:01' )).to eq(1)
            expect(subject.hms_to_seconds( '00:01:00' )).to eq(60)
            expect(subject.hms_to_seconds( '01:00:00' )).to eq(60*60)
            expect(subject.hms_to_seconds( '01:01:01')).to eq(60 * 60 + 60 + 1)
        end
    end

    describe '#exception_jail' do
        context 'when no error occurs' do
            it 'returns the return value of the block' do
                expect(subject.exception_jail { :stuff }).to eq(:stuff)
            end
        end

        context "when a #{RuntimeError} occurs" do
            context 'and raise_exception is' do
                context 'default' do
                    it 're-raises the exception' do
                        expect do
                            subject.exception_jail { raise }
                        end.to raise_error RuntimeError
                    end
                end

                context 'true' do
                    it 're-raises the exception' do
                        expect do
                            subject.exception_jail( true ) { raise }
                        end.to raise_error RuntimeError
                    end
                end

                context 'false' do
                    it 'returns nil' do
                        expect(subject.exception_jail( false ) { raise }).to be_nil
                    end
                end
            end
        end

        context "when an #{Exception} occurs" do
            context 'and raise_exception is' do
                context 'default' do
                    it 'does not rescue it' do
                        expect do
                            subject.exception_jail { raise Exception }
                        end.to raise_error Exception
                    end
                end

                context 'true' do
                    it 'does not rescue it' do
                        expect do
                            subject.exception_jail( true ) { raise Exception }
                        end.to raise_error Exception
                    end
                end

                context 'false' do
                    it 'does not rescue it' do
                        expect do
                            subject.exception_jail( false ) { raise Exception }
                        end.to raise_error Exception
                    end
                end
            end
        end
    end

end
