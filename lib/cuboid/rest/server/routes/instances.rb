module Cuboid
module Rest
class Server
module Routes

module Instances

    def self.registered( app )

        # List instances.
        app.get '/instances' do
            update_from_scheduler

            json instances.keys.inject({}){ |h, k| h.merge! k => {} }
        end

        # Create
        app.post '/instances' do
            max_utilization! if !agent && System.max_utilization?

            options = ::JSON.load( request.body.read ) || {}

            instance = get_instance
            max_utilization! if !instance

            handle_error proc { instance.shutdown } do
                instance.run( options )
            end

            instances[instance.token] = instance

            json id: instance.token
        end

        # Progress
        app.get '/instances/:instance' do
            ensure_instance!

            session[params[:instance]] ||= {
                seen_errors:  0,
            }

            data = instance_for( params[:instance] ) do |instance|
                instance.progress(
                    with:    [
                                 errors:  session[params[:instance]][:seen_errors],
                             ]
                )
            end

            session[params[:instance]][:seen_errors] += data[:errors].size

            json data
        end

        app.put '/instances/:instance/scheduler' do |instance|
            ensure_scheduler!
            ensure_instance!

            handle_error do
                instance = instances.delete( instance )
                instance.close

                json scheduler.attach( instance.url, instance.token )
            end
        end

        app.get '/instances/:instance/summary' do
            ensure_instance!

            instance_for( params[:instance] ) do |instance|
                json instance.progress
            end
        end

        app.get '/instances/:instance/report.crf' do
            ensure_instance!
            content_type 'application/octet-stream'

            instance_for( params[:instance] ) do |instance|
                instance.generate_report.to_crf
            end
        end

        app.get '/instances/:instance/report.json' do
            ensure_instance!

            instance_for( params[:instance] ) do |instance|
                instance.generate_report.to_rpc_data.to_json
            end
        end

        app.put '/instances/:instance/pause' do
            ensure_instance!

            instance_for( params[:instance] ) do |instance|
                json instance.pause!
            end
        end

        app.put '/instances/:instance/resume' do
            ensure_instance!

            instance_for( params[:instance] ) do |instance|
                json instance.resume!
            end
        end

        # Abort/shutdown
        app.delete '/instances/:instance' do
            ensure_instance!
            id = params[:instance]

            instance = instances[id]
            handle_error { instance.shutdown }

            instances.delete( id ).close

            session.delete params[:instance]

            json nil
        end

    end

end

end
end
end
end
