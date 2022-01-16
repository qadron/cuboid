class RPCAPI

    # RPC client:
    #   instance.custom.foo
    def foo
        'bar'
    end

    # RPC client:
    #   instance.custom.application_access
    def application_access
        MyApp.my_attr
    end

end
