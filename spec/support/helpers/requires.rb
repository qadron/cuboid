def require_lib( path )
    require Cuboid::Options.paths.lib + path
end

def require_testee
    require Kernel.caller.first.split( ':' ).first.
                gsub( '/spec/cuboid', '/lib/cuboid' ).gsub( '_spec', '' )
end
