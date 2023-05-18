require 'typhoeus'
require 'json'

def response
    if @last_response.headers['Content-Type'].include? 'json'
        data = JSON.load( @last_response.body )
    else
        data = @last_response.body
    end
    {
      code: @last_response.code,
      data: data
    }
end

def response_code
    response[:code]
end

def response_data
    response[:data]
end

def request( method, resource = nil, parameters = nil )
    options = {}

    if parameters
        if method == :get
            options[:params] = parameters
        else
            options[:body] = parameters.to_json
        end
    end

    @last_response = Typhoeus.send(
      method,
      "http://127.0.0.1:7331/#{resource}",
      options
    )
end
