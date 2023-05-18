require 'spec_helper'

describe Cuboid::RPC::Client::Instance do

    let(:subject) { instance_spawn application: "#{fixtures_path}/mock_app.rb", daemonize: true }

    context 'when connecting to an instance' do
        context 'which requires a token' do
            context 'with a valid token' do
                it 'connects successfully' do
                    expect(subject.alive?).to be_truthy
                end
            end

            context 'with an invalid token' do
                it 'should fail to connect' do
                    expect do
                        described_class.new( subject.url, 'blah' ).alive?
                    end.to raise_error Toq::Exceptions::InvalidToken
                end
            end
        end
    end

    describe '#options' do
        let(:options) { subject.options }

        describe '#set' do
            let(:authorized_by) { 'tasos.laskos@gmail.com' }

            it 'allows batch assigning using a hash' do
                expect(options.set( authorized_by: authorized_by )).to be_truthy
                expect(options.authorized_by).to eq(authorized_by)
            end
        end
    end

end
