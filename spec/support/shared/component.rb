shared_examples_for "component" do

    before :all do
        @name = self.class.metadata[:example_group][:description]
    end

    let(:name) { @name }
    let(:component_name) { name }
    let(:framework) { Cuboid::Framework.unsafe }
    let(:session) { framework.session }
    let(:http) { Cuboid::HTTP::Client }
    let(:options) { Cuboid::Options }

    def self.use_https
        @use_https = true
    end

    def url
        @url ||= web_server_url_for( @use_https ? "#{name}_https" : name ) + '/'
    rescue
        raise "Could not find server for '#{name}' component."
    end

    def yaml_load( yaml )
        YAML.load yaml.gsub( '__URL__', url )
    end

    def run
        framework.run
    end
end
