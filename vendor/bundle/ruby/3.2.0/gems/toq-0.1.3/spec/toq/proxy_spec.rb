require 'spec_helper'

class Translator < Toq::Proxy

    translate :foo do |response|
        response.map(&:to_s)
    end

    translate :delay do |response, arguments|
        [arguments, response.map(&:to_s)]
    end

end

describe Toq::Proxy do

    def wait
        Raktr.global.wait rescue Raktr::Error::NotRunning
    end

    before(:each) do
        if Raktr.global.running?
            Raktr.stop
        end

        Raktr.global.run_in_thread
    end

    let(:translated_arguments) do
        arguments.map(&:to_s)
    end
    let(:arguments) do
        [
            'one',
            2,
            { three: 3 },
            [ 4 ]
        ]
    end
    let(:reactor) { Raktr.global }
    let(:client) { start_client( rpc_opts ) }
    let(:handler) { 'test' }
    let(:translator) { Translator.new( client, handler ) }
    subject do
        Toq::Proxy.new( client, handler )
    end

    it 'forwards synchronous calls' do
        subject.foo( arguments ).should == arguments
    end

    it 'forwards synchronous calls' do
        response = nil
        subject.foo( arguments ) do |res|
            response = res
            Raktr.stop
        end
        wait

        response.should == arguments
    end

    describe '.translate' do
        context 'when a synchronous call' do
            context 'does not return an exception' do
                it 'returns the translated result' do
                    translator.foo( arguments ).should == translated_arguments
                end
            end

            context 'returns an exception' do
                it 'returns the exception'
            end
        end

        context 'when an asynchronous call' do
            context 'does not result in an exception' do
                it 'calls the block with the translated result' do
                    response = nil
                    translator.foo( arguments ) do |res|
                        response = res
                        Raktr.stop
                    end
                    wait

                    response.should == translated_arguments
                end
            end

            context 'results in an exception' do
                it 'calls the block with the exception'
            end
        end

        it 'passes the method arguments to the translator' do
            translator.delay( arguments ).should == [arguments, translated_arguments]
        end
    end
end
