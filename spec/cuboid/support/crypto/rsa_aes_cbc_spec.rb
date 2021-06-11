require 'spec_helper'
require 'tempfile'

describe Cuboid::Support::Crypto::RSA_AES_CBC do

    SEED = 'seed data'

    let(:public_key_file_path) do
        key  = private_key.public_key
        file = Tempfile.new( 'public_key.pem' )
        file.write( key.to_pem )
        file.close
        file.path
    end
    let(:private_key_file_path) do
        file = Tempfile.new( 'private_key.pem' )
        file.write( private_key.to_pem )
        file.close
        file.path
    end
    let(:private_key) { OpenSSL::PKey::RSA.generate( 1024 ) }
    subject { described_class.new( public_key_file_path, private_key_file_path ) }

    it 'generates matching encrypted and decrypted data' do
        expect(subject.decrypt( subject.encrypt( SEED ) )).to eq(SEED)
    end

end
