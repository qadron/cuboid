def web_server_manager
    ENV['WEB_SERVER_DISPATCHER'] ? WebServerClient.instance : WebServerManager
end

def web_server_url_for( *args )
    web_server_manager.url_for( *args )
end

def web_server_spawn( *args )
    web_server_manager.spawn( *args )
end

def web_server_killall
    web_server_manager.killall
end
