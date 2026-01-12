require 'spec_helper'

class Toq::Server
    public :async?, :async_check, :object_exist?
    attr_accessor :proxy
end

describe Toq::Server do
    let(:options) { rpc_opts.merge( port: 7333 ) }
    subject { start_server( options, true ) }
    let(:server) { start_server( options ) }
    let(:client) { start_client( options ) }

    before :all do
        Thread.new { server }
        client
    end

    describe '#initialize' do
        it 'should be able to properly setup class options' do
            subject.opts.should == options
        end

        context 'when passed no connection information' do
            it 'raises ArgumentError' do
                begin
                    described_class.new({})
                rescue => e
                    e.should be_kind_of ArgumentError
                end
            end
        end

        context 'when passed a host but not a port' do
            it 'raises ArgumentError' do
                begin
                    described_class.new( host: 'test' )
                rescue => e
                    e.should be_kind_of ArgumentError
                end
            end
        end

        context 'when passed a port but not a host' do
            it 'raises ArgumentError' do
                begin
                    described_class.new( port: 9999 )
                rescue => e
                    e.should be_kind_of ArgumentError
                end
            end
        end

        context 'when passed an invalid port' do
            it 'raises ArgumentError' do
                begin
                    described_class.new( host: 'tt', port: 'blah' )
                rescue => e
                    e.should be_kind_of ArgumentError
                end
            end
        end
    end

    it 'retains the supplied token' do
        subject.token.should == options[:token]
    end

    it 'has a Logger' do
        subject.logger.class.should == ::Logger
    end

    context 'when a method is public' do
        it 'can be called' do
            expect( client.call('test.in_child') ).to be_truthy
        end
    end

    context 'when a method is private' do
        it 'cannot be called' do
            expect { client.call('test.private_method') }.to raise_error Toq::Exceptions::UnsafeMethod
        end
    end

    context 'when a method is inherited' do
        it 'can be called' do
            expect( client.call('test.in_parent') ).to be_truthy
            expect( client.call('test.in_module') ).to be_truthy
        end
    end

    context 'when a method is inherited from Kernel' do
        it 'cannot be called' do
            expect { client.call('test.exec', 'ls') }.to raise_error Toq::Exceptions::UnsafeMethod
        end
    end

    context 'when a method is inherited from Object' do
        it 'cannot be called' do
            expect { client.call('test.included_modules') }.to raise_error Toq::Exceptions::UnsafeMethod
        end
    end

    describe '#alive?' do
        it 'returns true' do
            subject.should be_alive
        end
    end

    describe '#async?' do
        context 'when a method is async' do
            it 'returns true' do
                subject.async?( 'test', 'delay' ).should be_true
            end
        end

        context 'when a method is sync' do
            it 'returns false' do
                subject.async?( 'test', 'foo' ).should be_false
            end
        end
    end

    describe '#async_check' do
        context 'when a method is async' do
            it 'returns true' do
                subject.async_check( Test.new.method( :delay ) ).should be_true
            end
        end

        context 'when a method is sync' do
            it 'returns false' do
                subject.async_check( Test.new.method( :foo ) ).should be_false
            end
        end
    end

    describe '#object_exist?' do
        context 'when an object exists' do
            it 'returns true' do
                subject.object_exist?( 'test' ).should be_true
            end
        end

        context 'when an object does not exist' do
            it 'returns false' do
                subject.object_exist?( 'foo' ).should be_false
            end
        end
    end

end
