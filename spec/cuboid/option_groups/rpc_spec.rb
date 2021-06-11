require 'spec_helper'

describe Cuboid::OptionGroups::RPC do
    include_examples 'option_group'
    subject { described_class.new }

    %w(server_socket server_external_address server_address server_port ssl_ca
        server_ssl_private_key server_ssl_certificate client_ssl_private_key
        client_ssl_certificate client_max_retries).each do |method|
        it { is_expected.to respond_to method }
        it { is_expected.to respond_to "#{method}=" }
    end

    describe '#to_client_options' do
        it 'returns RPC client options' do
            subject.connection_pool_size   = 2
            subject.client_max_retries     = 3
            subject.client_ssl_private_key = '2'
            subject.client_ssl_certificate = '3'
            subject.ssl_ca                 = '4'

            expect(subject.to_client_options).to eq(
                connection_pool_size: subject.connection_pool_size,
                max_retries:          subject.client_max_retries,
                ssl_ca:               subject.ssl_ca,
                ssl_pkey:             subject.client_ssl_private_key,
                ssl_cert:             subject.client_ssl_certificate
            )
        end
    end

    describe '#to_server_options' do
        it 'returns RPC server options' do
            subject.server_address          = 'blah'
            subject.server_external_address = 'fsfs'
            subject.server_port             = 2
            subject.server_socket           = '3'
            subject.ssl_ca                  = '4'
            subject.server_ssl_private_key  = '4'
            subject.server_ssl_certificate  = '4'

            expect(subject.to_server_options).to eq(
                host:             subject.server_address,
                external_address: subject.server_external_address,
                port:             subject.server_port,
                socket:           subject.server_socket,
                ssl_ca:           subject.ssl_ca,
                ssl_pkey:         subject.server_ssl_private_key,
                ssl_cert:         subject.server_ssl_certificate
            )
        end
    end
end
