require 'spec_helper'
require "#{Cuboid::Options.paths.lib}/rest/server"

describe Cuboid::Rest::Server do
    include RequestHelpers

    before(:each) do
        app.reset
        Cuboid::Options.system.max_slots = 10
        Cuboid::Options.paths.application = "#{fixtures_path}/mock_app.rb"
    end

    let(:options) {{}}
    let(:url) { tpl_url % id }
    let(:id) { @id }
    let(:non_existent_id) { 'stuff' }

    let(:agent) { Cuboid::Processes::Agents.spawn }
    let(:scheduler) { Cuboid::Processes::Schedulers.spawn }

    def create_instance
        post '/instances', options
        response_data['id']
    end

    context 'supports compressing as' do
        ['gzip'].each do |compression_method|

            it compression_method do
                get '/', {}, { 'HTTP_ACCEPT_ENCODING' => compression_method }
                expect( response.headers['Content-Encoding'] ).to eq compression_method.split( ',' ).first
            end

        end
    end

    context 'when the client does not support compression' do
        it 'does not compress the response' do
            get '/'
            expect(response.headers['Content-Encoding']).to be_nil
        end
    end

    context 'when authentication' do
        let(:username) { nil }
        let(:password) { nil }
        let(:userpwd) { "#{username}:#{password}" }
        let(:url) { "http://localhost:#{Cuboid::Options.rpc.server_port}/instances" }

        before do
            Cuboid::Options.datastore['username'] = username
            Cuboid::Options.datastore['password'] = password

            Cuboid::Options.rpc.server_port = Cuboid::Utilities.available_port
            Cuboid::Processes::Manager.spawn( :rest_service )

            sleep 0.1 while Typhoeus.get( url ).code == 0
        end

        after do
            Cuboid::Processes::Manager.killall
        end

        context 'username' do
            let(:username) { 'username' }

            context 'is configured' do
                it 'requires authentication' do
                    expect(Typhoeus.get( url ).code).to eq 401
                    expect(Typhoeus.get( url, userpwd: userpwd ).code).to eq 200
                end
            end
        end

        context 'password' do
            let(:password) { 'password' }

            context 'is configured' do
                it 'requires authentication' do
                    expect(Typhoeus.get( url ).code).to eq 401
                    expect(Typhoeus.get( url, userpwd: userpwd ).code).to eq 200
                end
            end
        end
    end

    describe 'SSL options', if: !Cuboid.windows? do
        let(:ssl_key) { nil }
        let(:ssl_cert) { nil }
        let(:ssl_ca) { nil }
        let(:url) { "http://localhost:#{Cuboid::Options.rpc.server_port}/instances" }
        let(:https_url) { "https://localhost:#{Cuboid::Options.rpc.server_port}/instances" }

        before do
            Cuboid::Options.rpc.ssl_ca                 = ssl_ca
            Cuboid::Options.rpc.server_ssl_private_key = ssl_key
            Cuboid::Options.rpc.server_ssl_certificate = ssl_cert

            Cuboid::Options.rpc.server_port = Cuboid::Utilities.available_port
            Cuboid::Processes::Manager.spawn( :rest_service )

            sleep 0.1 while Typhoeus.get( url ).return_code == :couldnt_connect
        end

        after do
            Cuboid::Processes::Manager.killall
        end

        describe 'when key and certificate is given' do
            let(:ssl_key) { "#{support_path}/pems/server/key.pem" }
            let(:ssl_cert) { "#{support_path}/pems/server/cert.pem" }

            describe 'when no CA is given' do
                it 'disables peer verification' do
                    expect(Typhoeus.get( https_url, ssl_verifypeer: false ).code).to eq 200
                end
            end

            describe 'a CA is given' do
                let(:ssl_ca) { "#{support_path}/pems/cacert.pem" }

                it 'enables peer verification' do
                    expect(Typhoeus.get( https_url, ssl_verifypeer: false ).code).to eq 0

                    expect(Typhoeus.get(
                        https_url,
                        ssl_verifypeer: true,
                        sslcert:        "#{support_path}/pems/client/cert.pem",
                        sslkey:         "#{support_path}/pems/client/key.pem",
                        cainfo:         ssl_ca
                    ).code).to eq 200
                end
            end
        end

        describe 'when only key is given' do
            let(:ssl_key) { "#{support_path}/pems/server/key.pem" }

            it 'does not enable SSL' do
                expect(Typhoeus.get( url ).code).to eq 200
            end
        end

        describe 'when only cert is given' do
            let(:ssl_cert) { "#{support_path}/pems/server/cert.pem" }

            it 'does not enable SSL' do
                expect(Typhoeus.get( url ).code).to eq 200
            end
        end
    end

    describe 'GET /instances' do
        let(:tpl_url) { '/instances' }

        it 'lists ids for all instances' do
            ids = []
            2.times do
                ids << create_instance
            end

            get url

            ids.each do |id|
                expect(response_data[id]).to eq({})
            end
        end

        context 'when there is a Scheduler' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'includes its running instances' do
                id = scheduler.push( options )
                sleep 0.1 while scheduler.running.empty?

                get url
                expect(response_data).to include id
            end

            context 'when a running instance completes' do
                it 'is removed' do
                    scheduler.push( options )
                    sleep 0.1 while scheduler.completed.empty?

                    get url
                    expect(response_data).to be_empty
                end
            end
        end
    end

    describe 'POST /instances' do
        let(:tpl_url) { '/instances' }

        it 'creates an instance' do
            post url, options
            expect(response_code).to eq 200
        end

        context 'when given invalid options' do
            it 'returns a 500' do
                post url, invalid: 'blah'

                expect(response_code).to eq 500
                expect(response_data['error']).to eq 'Arachni::RPC::Exceptions::RemoteException'
                expect(response_data).to include 'backtrace'
            end

            it 'does not list the instance on the index' do
                get '/instances'
                ids = response_data.keys

                post url, invalid: 'blah'

                get '/instances'
                expect(response_data.keys - ids).to be_empty
            end
        end

        context 'when the system is at max utilization' do
            it 'returns a 503' do
                Cuboid::Options.system.max_slots = 1

                post url, options
                expect(response_code).to eq 200

                sleep 1

                post url, options
                expect(response_code).to eq 503
                expect(response_data['error']).to eq 'Service unavailable: System is at maximum ' +
                                                         'utilization, slot limit reached.'
            end
        end

        context 'when a Agent has been set' do

            it 'uses it' do
                put '/agent/url', agent.url

                get "/grid/#{agent.url}"
                expect(response_data['running_instances']).to be_empty

                create_instance

                get "/grid/#{agent.url}"
                expect(response_data['running_instances'].size).to eq 1
            end
        end
    end

    describe 'GET /instances/:instance' do
        let(:tpl_url) { '/instances/%s' }

        before do
            @id = create_instance
        end

        it 'gets progress info' do
            loop do
                get url
                break if !response_data['busy']
                sleep 0.5
            end

            %w(errors status busy messages statistics).each do |key|
                expect(response_data).to include key
            end

            %w(statistics).each do |key|
                expect(response_data.any?).to be_truthy
            end
        end

        context 'when a session is maintained' do
            it 'only returns new errors'
        end

        context 'when a session is not maintained' do
            it 'always returns all errors'
        end

        context 'when passed a non-existent id' do
            let(:id) { non_existent_id }

            it 'returns 404' do
                get url
                expect(response_code).to eq 404
            end
        end

        context 'when the instance is from the Scheduler' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'includes it' do
                @id = scheduler.push( options )
                sleep 0.1 while scheduler.running.empty?

                get url
                expect(response_data).to include 'busy'
            end

            context 'when the instance completes' do
                it 'is removed' do
                    @id = scheduler.push( options )
                    sleep 0.1 while scheduler.completed.empty?

                    get url
                    expect(response_code).to be 404
                end
            end
        end
    end

    describe 'PUT /instances/:instance/scheduler' do
        let(:tpl_url) { '/instances/%s/scheduler' }

        before do
            @id = create_instance
        end

        context 'when there is a Scheduler' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'moves the instance to the Scheduler' do
                expect(scheduler.running).to be_empty

                put url
                expect(response_code).to be 200
                expect(scheduler.running).to include @id
            end

            context 'but the instance could not be found' do
                it 'returns 404' do
                    @id = 'ss'

                    put url
                    expect(response_code).to be 404
                end
            end
        end

        context 'when there is no Scheduler' do
            it 'returns 501' do
                put url
                expect(response_code).to be 501
            end
        end
    end

    describe 'GET /instances/:instance/summary' do
        let(:tpl_url) { '/instances/%s/summary' }

        before do
            @id = create_instance
        end

        context 'when passed a non-existent id' do
            let(:id) { non_existent_id }

            it 'returns 404' do
                get url
                expect(response_code).to eq 404
            end
        end

        context 'when the instance is from the Scheduler' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'includes it' do
                @id = scheduler.push( options )
                sleep 0.1 while scheduler.running.empty?

                get url
                expect(response_data).to include 'busy'
            end

            context 'when the instance completes' do
                it 'is removed' do
                    @id = scheduler.push( options )
                    sleep 0.1 while scheduler.completed.empty?

                    get url
                    expect(response_code).to be 404
                end
            end
        end
    end

    describe 'GET /instances/:instance/report.crf' do
        let(:tpl_url) { "/instances/%s/report.crf" }

        before do
            @id = create_instance
        end

        it 'returns instance report' do
            get url

            file = Tempfile.new( "#{Dir.tmpdir}/report-#{Process.pid}.crf" )
            file.write last_response.body
            file.close

            expect(Cuboid::Report.load( file.path ).data).to eq 'My results.'
        end

        it 'has content-type application/octet-stream' do
            get url
            expect(last_response.headers['content-type']).to eq 'application/octet-stream'
        end

        context 'when passed a non-existent id' do
            let(:id) { non_existent_id }

            it 'returns 404' do
                get url
                expect(response_code).to eq 404
            end
        end
    end

    describe 'GET /instances/:instance/report.json' do
        let(:tpl_url) { "/instances/%s/report.json" }

        before do
            @id = create_instance
        end

        it 'returns instance report' do
            get url

            report = JSON.load( last_response.body )
            expect(MockApp.serializer.load report['data']).to eq 'My results.'
        end

        it 'has content-type application/json' do
            get url
            expect(last_response.headers['content-type']).to eq 'application/json'
        end

        context 'when passed a non-existent id' do
            let(:id) { non_existent_id }

            it 'returns 404' do
                get url
                expect(response_code).to eq 404
            end
        end
    end

    describe 'PUT /instances/:instance/pause' do
        let(:tpl_url) { '/instances/%s/pause' }

        before do
            @id = create_instance
        end

        it 'pauses the instance' do
            put url
            expect(response_code).to eq 200

            get "/instances/#{id}"
            expect(['pausing', 'paused']).to include response_data['status']
        end

        context 'when passed a non-existent id' do
            let(:id) { non_existent_id }

            it 'returns 404' do
                put url
                expect(response_code).to eq 404
            end
        end

        context 'when the instance is from the Scheduler' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'includes it' do
                @id = scheduler.push( options )
                sleep 0.1 while scheduler.running.empty?

                put url
                expect(response_code).to eq 200

                get "/instances/#{id}"
                expect(['pausing', 'paused']).to include response_data['status']
            end

            context 'when the instance completes' do
                it 'is removed' do
                    @id = scheduler.push( options )
                    sleep 0.1 while scheduler.completed.empty?

                    put url
                    expect(response_code).to be 404
                end
            end
        end
    end

    describe 'PUT /instances/:instance/resume' do
        let(:tpl_url) { '/instances/%s/resume' }

        before do
            @id = create_instance
        end

        it 'resumes the instance' do
            put "/instances/#{id}/pause"
            get "/instances/#{id}"

            expect(['pausing', 'paused']).to include response_data['status']

            put url
            get "/instances/#{id}"

            expect(['pausing', 'paused']).to_not include response_data['status']
        end

        context 'when passed a non-existent id' do
            let(:id) { non_existent_id }

            it 'returns 404' do
                put url
                expect(response_code).to eq 404
            end
        end

        context 'when the instance is from the Scheduler' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'includes it' do
                @id = scheduler.push( options )
                sleep 0.1 while scheduler.running.empty?

                put "/instances/#{id}/pause"
                get "/instances/#{id}"

                expect(['pausing', 'paused']).to include response_data['status']

                put url
                get "/instances/#{id}"

                expect(['running', 'done']).to include response_data['status']
            end

            context 'when the instance completes' do
                it 'is removed' do
                    @id = scheduler.push( options )
                    sleep 0.1 while scheduler.completed.empty?

                    put url
                    expect(response_code).to be 404
                end
            end
        end
    end
    
    describe 'DELETE /instances/:instance' do
        let(:tpl_url) { '/instances/%s' }

        before do
            @id = create_instance
        end

        it 'aborts the instance' do
            get url
            expect(response_code).to eq 200

            delete url

            get "/instances/#{id}"
            expect(response_code).to eq 404
        end

        context 'when passed a non-existent id' do
            let(:id) { non_existent_id }

            it 'returns 404' do
                delete url
                expect(response_code).to eq 404
            end
        end

        context 'when the instance is from the Scheduler' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'includes it' do
                @id = scheduler.push( options )
                sleep 0.1 while scheduler.running.empty?

                delete url
                expect(response_code).to eq 200

                sleep 0.1 while scheduler.failed.empty?

                expect(scheduler.failed).to include @id
            end

            context 'when the instance completes' do
                it 'is removed' do
                    @id = scheduler.push( options )
                    sleep 0.1 while scheduler.completed.empty?

                    delete url
                    expect(response_code).to be 404
                end
            end
        end
    end

    describe 'GET /agent/url' do
        let(:tpl_url) { '/agent/url' }

        it 'returns the Agent' do
            put url, agent.url
            expect(response_code).to eq 200

            get url
            expect(response_code).to eq 200
            expect(response_data).to eq agent.url
        end

        context 'when no Agent has been set' do
            it 'returns 501' do
                get url
                expect(response_code).to eq 501
                expect(response_data).to eq 'No Agent has been set.'
            end
        end
    end

    describe 'PUT /agent/url' do
        let(:tpl_url) { '/agent/url' }

        it 'sets the Agent' do
            put url, agent.url
            expect(response_code).to eq 200
        end

        context 'when passed a non-existent URL' do
            let(:id) { non_existent_id }

            it 'returns 500' do
                put url, 'localhost:383838'
                expect(response_code).to eq 500
                expect(response_data['error']).to eq 'Arachni::RPC::Exceptions::ConnectionError'
            end
        end
    end

    describe 'DELETE /agent/url' do
        let(:tpl_url) { '/agent/url' }

        it 'removes the the Agent' do
            put url, agent.url
            expect(response_code).to eq 200

            delete url
            expect(response_code).to eq 200

            get url, agent.url
            expect(response_code).to eq 501
        end

        context 'when no Agent has been set' do
            it 'returns 501' do
                delete url
                expect(response_code).to eq 501
                expect(response_data).to eq 'No Agent has been set.'
            end
        end
    end

    describe 'GET /grid' do
        let(:agent) { Cuboid::Processes::Agents.grid_spawn }
        let(:tpl_url) { '/grid' }

        it 'returns Grid info' do
            put '/agent/url', agent.url
            expect(response_code).to eq 200

            get url
            expect(response_code).to eq 200
            expect(response_data.sort).to eq ([agent.url] + agent.node.peers).sort
        end

        context 'when no Agent has been set' do
            it 'returns 501' do
                get url
                expect(response_code).to eq 501
                expect(response_data).to eq 'No Agent has been set.'
            end
        end
    end

    describe 'GET /grid/:agent' do
        let(:agent) { Cuboid::Processes::Agents.grid_spawn }
        let(:tpl_url) { '/grid/%s' }

        it 'returns Agent info' do
            put '/agent/url', agent.url
            expect(response_code).to eq 200

            @id = agent.url

            get url
            expect(response_code).to eq 200
            expect(response_data).to eq agent.statistics
        end

        context 'when no Agent has been set' do
            it 'returns 501' do
                @id = 'localhost:2222'

                get url
                expect(response_code).to eq 501
                expect(response_data).to eq 'No Agent has been set.'
            end
        end
    end

    describe 'DELETE /grid/:agent' do
        let(:agent) { Cuboid::Processes::Agents.grid_spawn }
        let(:tpl_url) { '/grid/%s' }

        it 'unplugs the Agent from the Grid' do
            put '/agent/url', agent.url
            expect(response_code).to eq 200

            @id = agent.url

            expect(agent.node.grid_member?).to be_truthy

            delete url
            expect(response_code).to eq 200
            expect(agent.node.grid_member?).to be_falsey
        end

        context 'when no Agent has been set' do
            it 'returns 501' do
                @id = 'localhost:2222'

                delete url
                expect(response_code).to eq 501
                expect(response_data).to eq 'No Agent has been set.'
            end
        end
    end

    describe 'GET /scheduler' do
        let(:tpl_url) { '/scheduler' }

        context 'when a Scheduler has been set' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'lists schedulerd instances grouped by priority' do
                low    = scheduler.push( options, priority: -1 )
                high   = scheduler.push( options, priority: 1 )
                medium = scheduler.push( options, priority: 0 )

                get url
                expect(response_code).to eq 200
                expect(response_data.to_a).to eq({
                    '1'  => [high],
                    '0'  => [medium],
                    '-1' => [low]
                }.to_a)
            end
        end

        context 'when no Scheduler has been set' do
            it 'returns 501' do
                get url

                expect(response_code).to eq 501
                expect(response_data).to eq 'No Scheduler has been set.'
            end
        end
    end

    describe 'POST /scheduler' do
        let(:tpl_url) { '/scheduler' }

        context 'when a Scheduler has been set' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'pushes the instance to the Scheduler' do
                post url, [options, priority: 9]

                expect(response_code).to eq 200

                id = response_data['id']

                expect(scheduler.get(id)).to eq(
                    'options' => options,
                    'priority' => 9
                )
            end

            context 'when given invalid options' do
                it 'returns a 500' do
                    post url, invalid: 'blah'

                    expect(response_code).to eq 500
                    expect(response_data['error']).to eq 'Arachni::RPC::Exceptions::RemoteException'
                    expect(response_data).to include 'backtrace'
                end
            end
        end

        context 'when no Scheduler has been set' do
            it 'returns 501' do
                get url

                expect(response_code).to eq 501
                expect(response_data).to eq 'No Scheduler has been set.'
            end
        end
    end

    describe 'GET /scheduler/url' do
        let(:tpl_url) { '/scheduler/url' }

        context 'when a Scheduler has been set' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'returns its URL' do
                get url
                expect(response_code).to eq 200
                expect(response_data).to eq scheduler.url
            end
        end

        context 'when no Scheduler has been set' do
            it 'returns 501' do
                get url

                expect(response_code).to eq 501
                expect(response_data).to eq 'No Scheduler has been set.'
            end
        end
    end

    describe 'PUT /scheduler/url' do
        let(:tpl_url) { '/scheduler/url' }


        it 'sets the Scheduler URL' do
            put url, scheduler.url
            expect(response_code).to eq 200
        end

        context 'when given an invalid URL' do
            it 'returns 500' do
                put url, 'localhost:393939'

                expect(response_code).to eq 500
                expect(response_data['error']).to eq 'Arachni::RPC::Exceptions::ConnectionError'
                expect(response_data['description']).to include 'Connection closed'
            end
        end
    end

    describe 'DELETE /scheduler/url' do
        let(:tpl_url) { '/scheduler/url' }

        context 'when a Scheduler has been set' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'removes it' do
                delete url
                expect(response_code).to eq 200

                get '/scheduler/url'
                expect(response_code).to eq 501
            end
        end

        context 'when no Scheduler has been set' do
            it 'returns 501' do
                get url

                expect(response_code).to eq 501
                expect(response_data).to eq 'No Scheduler has been set.'
            end
        end
    end

    describe 'GET /scheduler/running' do
        let(:tpl_url) { '/scheduler/running' }

        context 'when a Scheduler has been set' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'returns running instances' do
                get url
                expect(response_data.empty?).to be_truthy

                @id = scheduler.push( options )
                sleep 0.1 while scheduler.running.empty?

                get url
                expect(response_data.size).to be 1
                expect(response_data[@id]).to include 'url'
                expect(response_data[@id]).to include 'token'
                expect(response_data[@id]).to include 'pid'
            end
        end

        context 'when no Scheduler has been set' do
            it 'returns 501' do
                get url

                expect(response_code).to eq 501
                expect(response_data).to eq 'No Scheduler has been set.'
            end
        end
    end

    describe 'GET /scheduler/completed' do
        let(:tpl_url) { '/scheduler/completed' }

        context 'when a Scheduler has been set' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'returns completed instances' do
                get url
                expect(response_data.empty?).to be_truthy

                @id = scheduler.push( options )
                sleep 0.1 while scheduler.completed.empty?

                get url
                expect(response_data.size).to be 1
                expect(File.exists? response_data[@id]).to be true
            end
        end

        context 'when no Scheduler has been set' do
            it 'returns 501' do
                get url

                expect(response_code).to eq 501
                expect(response_data).to eq 'No Scheduler has been set.'
            end
        end
    end

    describe 'GET /scheduler/failed' do
        let(:tpl_url) { '/scheduler/failed' }

        context 'when a Scheduler has been set' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'returns failed instances' do
                get url
                expect(response_data.empty?).to be_truthy

                @id = scheduler.push( options )
                sleep 0.1 while scheduler.running.empty?
                Cuboid::Processes::Manager.kill scheduler.running.values.first['pid']
                sleep 0.1 while scheduler.failed.empty?

                get url
                expect(response_data.size).to be 1
                expect(response_data[@id]['error']).to eq 'Arachni::RPC::Exceptions::ConnectionError'
                expect(response_data[@id]['description']).to include 'Connection closed [Connection refused - connect(2) for'
            end
        end

        context 'when no Scheduler has been set' do
            it 'returns 501' do
                get url

                expect(response_code).to eq 501
                expect(response_data).to eq 'No Scheduler has been set.'
            end
        end
    end

    describe 'GET /scheduler/size' do
        let(:tpl_url) { '/scheduler/size' }

        context 'when a Scheduler has been set' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'returns the scheduler size' do
                get url
                expect(response_data).to eq 0

                10.times do
                    scheduler.push( options )
                end

                get url
                expect(response_data).to be 10
            end
        end

        context 'when no Scheduler has been set' do
            it 'returns 501' do
                get url

                expect(response_code).to eq 501
                expect(response_data).to eq 'No Scheduler has been set.'
            end
        end
    end

    describe 'DELETE /scheduler' do
        let(:tpl_url) { '/scheduler' }

        context 'when a Scheduler has been set' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'empties the scheduler' do
                expect(scheduler.empty?).to be_truthy

                10.times do
                    scheduler.push( options )
                end

                expect(scheduler.any?).to be_truthy

                delete url
                expect(scheduler.empty?).to be_truthy
            end
        end

        context 'when no Scheduler has been set' do
            it 'returns 501' do
                get url

                expect(response_code).to eq 501
                expect(response_data).to eq 'No Scheduler has been set.'
            end
        end
    end

    describe 'GET /scheduler/:instance' do
        let(:tpl_url) { '/scheduler/%s' }

        context 'when a Scheduler has been set' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'returns info for the Queued instance' do
                @id = scheduler.push( options )

                get url
                expect(response_code).to be 200
                expect(response_data).to eq({
                    'options' => options,
                    'priority' => 0
                })
            end

            context 'when the instance could not be found' do
                let(:id) { non_existent_id }

                it 'returns 404' do
                    get url

                    expect(response_code).to eq 404
                    expect(response_data).to eq 'Instance not in Scheduler.'
                end
            end
        end

        context 'when no Scheduler has been set' do
            let(:id) { non_existent_id }

            it 'returns 501' do
                get url

                expect(response_code).to eq 501
                expect(response_data).to eq 'No Scheduler has been set.'
            end
        end
    end

    describe 'PUT /scheduler/:instance/detach' do
        let(:tpl_url) { '/scheduler/%s/detach' }

        context 'when a Scheduler has been set' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'detaches the instance from the Scheduler' do
                @id = scheduler.push( options )
                sleep 0.1 while scheduler.running.empty?

                put url
                expect(response_code).to be 200
                expect(scheduler.running).to be_empty
                expect(scheduler.completed).to be_empty
                expect(scheduler.failed).to be_empty

                get '/instances'
                expect(response_code).to be 200
                expect(response_data.keys).to eq [@id]
            end

            context 'when the instance could not be found' do
                let(:id) { non_existent_id }

                it 'returns 404' do
                    put url

                    expect(response_code).to eq 404
                    expect(response_data).to eq 'Instance not in Scheduler.'
                end
            end
        end

        context 'when no Scheduler has been set' do
            let(:id) { non_existent_id }

            it 'returns 501' do
                put url

                expect(response_code).to eq 501
                expect(response_data).to eq 'No Scheduler has been set.'
            end
        end
    end

    describe 'DELETE /scheduler/:instance' do
        let(:tpl_url) { '/scheduler/%s' }

        context 'when a Scheduler has been set' do
            before do
                put '/scheduler/url', scheduler.url
            end

            it 'removes the instance from the Scheduler' do
                @id = scheduler.push( options )

                expect(scheduler.any?).to be_truthy

                delete url

                expect(response_code).to be 200
                expect(scheduler.empty?).to be_truthy
            end

            context 'when the instance could not be found' do
                let(:id) { non_existent_id }

                it 'returns 404' do
                    delete url

                    expect(response_code).to eq 404
                    expect(response_data).to eq 'Instance not in Scheduler.'
                end
            end
        end

        context 'when no Scheduler has been set' do
            let(:id) { non_existent_id }

            it 'returns 501' do
                delete url

                expect(response_code).to eq 501
                expect(response_data).to eq 'No Scheduler has been set.'
            end
        end
    end
end
