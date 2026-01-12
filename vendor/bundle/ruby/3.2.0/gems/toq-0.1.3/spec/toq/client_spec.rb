require 'spec_helper'

describe Toq::Client do

    def wait
        reactor.wait rescue reactor::Error::NotRunning
    end

    before(:each) do
        reactor.stop if reactor.running?
    end

    let(:arguments) do
        [
            'one',
            2,
            { three: 3 },
            [ 4 ]
        ]
    end
    let(:reactor) { subject.reactor }
    let(:handler) { 'test' }
    let(:remote_method) { 'foo' }
    let(:options) { rpc_opts }
    subject do
        start_client( options )
    end

    def call( &block )
        subject.call( "#{handler}.#{remote_method}", arguments, &block )
    end

    describe '#initialize' do
        let(:options) { rpc_opts.merge( role: :client ) }

        it 'assigns instance options (including :role)' do
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

        describe 'option' do
            describe :socket, if: Raktr.supports_unix_sockets? do
                let(:options) { rpc_opts_with_socket }

                it 'connects to it' do
                    call.should == arguments
                end

                context 'when under heavy load' do
                    it 'retains stability and consistency' do
                        n    = 10_000
                        cnt  = 0

                        mismatches = []

                        n.times do |i|
                            arg = 'a' * i
                            subject.call( "#{handler}.#{remote_method}", arg ) do |res|
                                cnt += 1
                                mismatches << [i, arg, res] if arg != res
                                reactor.stop if cnt == n || mismatches.any?
                            end
                        end
                        wait

                        cnt.should > 0
                        mismatches.should be_empty
                    end
                end

                context 'and connecting to a non-existent server' do
                    let(:options) { rpc_opts_with_socket.merge( socket: '/' ) }

                    it "returns #{Toq::Exceptions::ConnectionError}" do
                        response = nil
                        call do |res|
                            response = res
                            reactor.stop
                        end
                        wait

                        response.should be_rpc_connection_error
                        response.should be_kind_of Toq::Exceptions::ConnectionError
                    end
                end

                context 'when passed an invalid socket path' do
                    it 'raises ArgumentError' do
                        begin
                            described_class.new( socket: 'blah' )
                        rescue => e
                            e.should be_kind_of ArgumentError
                        end
                    end
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

    describe '#to_rpc_data' do
        it "serializes the client" do
            data = subject.to_rpc_data
            data.should be_kind_of Hash
            described_class.from_rpc_data( data ).call('test.foo', 12).should be_true
        end
    end

    describe '.from_rpc_data' do
        it "deserializes the client" do
            pending
        end
    end

    describe '#call' do
        context 'when calling a remote method that delays its results' do
            let(:remote_method) { 'delay' }

            it 'it supports it' do
                call.should == arguments
            end
        end

        context 'when calling a remote method that defers its results' do
            let(:remote_method) { 'defer' }

            it 'it supports it' do
                call.should == arguments
            end
        end

        context 'when under heavy load' do
            it 'retains stability and consistency' do
                n   = 10_000
                cnt = 0

                mismatches = []

                n.times do |i|
                    arg = 'a' * i
                    subject.call( "#{handler}.#{remote_method}", arg ) do |res|
                        cnt += 1
                        mismatches << [i, arg, res] if arg != res
                        reactor.stop if cnt == n || mismatches.any?
                    end
                end

                wait

                cnt.should > 0
                mismatches.should be_empty
            end
        end

        context 'when using Threads' do
            it 'should be able to perform synchronous calls' do
                arguments.should == call
            end

            it 'should be able to perform asynchronous calls' do
                response = nil
                call do |res|
                    response = res
                    reactor.stop
                end
                wait

                response.should == arguments
            end
        end

        context 'when run inside the Reactor loop' do
            it 'should be able to perform asynchronous calls' do
                response = nil

                reactor.run do
                    call do |res|
                        response = res
                        reactor.stop
                    end
                end

                response.should == arguments
            end

            it 'should not be able to perform synchronous calls' do
                exception = nil

                reactor.run do
                    begin
                        call
                    rescue => e
                        exception = e
                        reactor.stop
                    end
                end

                exception.should be_kind_of RuntimeError
            end
        end

        context 'when performing an asynchronous call' do
            context 'and connecting to a non-existent server' do
                let(:options) { rpc_opts.merge( host: 'dddd', port: 999339 ) }

                it "returns #{Toq::Exceptions::ConnectionError}" do
                    response = nil
                    call do |res|
                        response = res
                        reactor.stop
                    end
                    wait

                    response.should be_rpc_connection_error
                    response.should be_kind_of Toq::Exceptions::ConnectionError
                end
            end

            context 'and requesting a non-existent object' do
                let(:handler) { 'bar' }

                it "returns #{Toq::Exceptions::InvalidObject}" do
                    response = nil

                    call do |res|
                        response = res
                        reactor.stop
                    end
                    wait

                    response.should be_rpc_invalid_object_error
                    response.should be_kind_of Toq::Exceptions::InvalidObject
                end
            end

            # context 'and requesting a non-public method' do
            #     let(:remote_method) { 'bar' }
            #
            #     it "returns #{Toq::Exceptions::InvalidMethod}" do
            #         response = nil
            #
            #         call do |res|
            #             response = res
            #             reactor.stop
            #         end
            #         wait
            #
            #         response.should be_rpc_invalid_method_error
            #         response.should be_kind_of Toq::Exceptions::InvalidMethod
            #     end
            # end

            context 'and there is a remote exception' do
                let(:remote_method) { :exception }

                it "returns #{Toq::Exceptions::RemoteException}" do
                    response = nil
                    call do |res|
                        response = res
                        reactor.stop
                    end
                    wait

                    response.should be_rpc_remote_exception
                    response.should be_kind_of Toq::Exceptions::RemoteException
                end
            end
        end

        context 'when performing a synchronous call' do
            context 'and connecting to a non-existent server' do
                let(:options) { rpc_opts.merge( host: 'dddd', port: 999339 ) }

               it "raises #{Toq::Exceptions::ConnectionError}" do
                   begin
                       call
                   rescue => e
                       e.rpc_connection_error?.should be_true
                       e.should be_kind_of Toq::Exceptions::ConnectionError
                   end
               end
            end

            context 'and requesting a non-existent object' do
                let(:handler) { 'bar' }

                it "raises #{Toq::Exceptions::InvalidObject}" do
                    begin
                        call
                    rescue => e
                        e.rpc_invalid_object_error?.should be_true
                        e.should be_kind_of Toq::Exceptions::InvalidObject
                    end
                end
            end

            # context 'and requesting a non-public method' do
            #     let(:remote_method) { 'bar' }
            #
            #     it "raises #{Toq::Exceptions::InvalidMethod}" do
            #         begin
            #             call
            #         rescue => e
            #             e.rpc_invalid_method_error?.should be_true
            #             e.should be_kind_of Toq::Exceptions::InvalidMethod
            #         end
            #     end
            # end

            context 'and there is a remote exception' do
                let(:remote_method) { :exception }

                it "raises #{Toq::Exceptions::RemoteException}" do
                    begin
                        call
                    rescue => e
                        e.rpc_remote_exception?.should be_true
                        e.should be_kind_of Toq::Exceptions::RemoteException
                    end
                end
            end
        end

        context 'when using valid SSL configuration' do
            let(:options) { rpc_opts_with_ssl_primitives }

            it 'should be able to establish a connection' do
                call.should == arguments
            end
        end

        context 'when using invalid SSL configuration' do
            let(:options) { rpc_opts_with_invalid_ssl_primitives }

            it 'should not be able to establish a connection' do
                response = nil

                reactor.run do
                    call do |res|
                        response = res
                        reactor.stop
                    end
                end

                response.should be_rpc_connection_error
            end
        end

        context 'when using mixed SSL configuration' do
            let(:options) { rpc_opts_with_mixed_ssl_primitives }

            it 'should not be able to establish a connection' do
                response = nil

                reactor.run do
                    call do |res|
                        response = res
                        reactor.stop
                    end
                end

                response.should be_rpc_connection_error
            end
        end
    end

end
