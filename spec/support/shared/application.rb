require "#{fixtures_path}/mock_app"

shared_examples_for 'application' do

    after(:each) { subject.reset }

    subject { MockApp.unsafe }
    let(:url) { web_server_url_for( :auditor ) }
    let(:f_url) { web_server_url_for( :framework ) }
end
