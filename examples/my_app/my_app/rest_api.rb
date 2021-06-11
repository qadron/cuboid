module RESTAPI
def self.registered( rest )

    # /instances/:id/custom/foo
    rest.get '/foo' do
        json 'bar'
    end

    # /instances/:id/custom/rpc-foo
    rest.get '/rpc-foo' do
        # Safely get access to an RPC client for the Instance.
        data = instance_for( params[:instance] ) do |instance|
            # Custom RPC API implementation.
            instance.custom.foo
        end

        json data
    end

    # /instances/:id/custom/application_access
    rest.get '/application_access' do
        # Safely get access to an RPC client for the Instance.
        data = instance_for( params[:instance] ) do |instance|
            # Custom RPC API implementation.
            instance.custom.application_access
        end

        json data
    end

end
end
