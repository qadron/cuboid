# coding: utf-8

Gem::Specification.new do |s|
    require_relative File.expand_path( File.dirname( __FILE__ ) ) + '/lib/cuboid/version'

    s.name              = 'cuboid'
    s.version           = Cuboid::VERSION
    s.date              = Time.now.strftime( '%Y-%m-%d' )
    s.summary           = 'An application-centric, decentralised and distributed computing solution. '

    s.homepage          = 'https://github.com/qadron/cuboid'
    s.email             = 'tasos.laskos@gmail.com'
    s.authors           = [ 'Tasos Laskos' ]
    s.licenses          = ['MIT']

    s.files            += Dir.glob( 'config/**/**' )
    s.files            += Dir.glob( 'lib/**/**' )
    s.files            += Dir.glob( 'logs/**/**' )
    s.files            += Dir.glob( 'components/**/**' )
    s.files            += Dir.glob( 'spec/**/**' )
    s.files            += %w(Gemfile Rakefile cuboid.gemspec)
    s.test_files        = Dir.glob( 'spec/**/**' )

    s.extra_rdoc_files  = %w(README.md LICENSE.md CHANGELOG.md)

    s.rdoc_options      = [ '--charset=UTF-8' ]

    s.add_dependency 'awesome_print',       '1.6.1'

    # Don't specify version, messes with the packages since they always grab the
    # latest one.
    s.add_dependency 'bundler'

    s.add_dependency 'concurrent-ruby',     '1.1.8'
    s.add_dependency 'concurrent-ruby-ext', '1.1.8'

    # For compressing/decompressing system state archives.
    s.add_dependency 'rubyzip',             '2.3.0'

    s.add_dependency 'childprocess',        '0.8.0'

    # RPC serialization.
    s.add_dependency 'msgpack',             '1.1.0'

    # Optimized JSON.
    s.add_dependency 'oj',                  '3.11.5'
    s.add_dependency 'oj_mimic_json',       '1.0.1'

    # Web server
    s.add_dependency 'puma',                '5.5.2'

    s.add_dependency 'rack',                '2.2.3'
    s.add_dependency 'rack-test'

    # REST API
    s.add_dependency 'sinatra',             '2.1.0'
    s.add_dependency 'sinatra-contrib',     '2.1.0'

    # RPC client/server implementation.
    s.add_dependency 'arachni-rpc',         '~> 0.2.1.4'

    s.add_dependency 'vmstat',              '2.3.0'
    s.add_dependency 'sys-proctable',       '1.1.5'

    s.description = <<DESCRIPTION
An application-centric, decentralised and distributed computing solution.
DESCRIPTION

end
