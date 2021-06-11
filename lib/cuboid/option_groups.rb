require_relative 'option_group'

# We need this to be available prior to loading the rest of the groups.
require_relative 'option_groups/paths'

Dir.glob( "#{File.dirname(__FILE__)}/option_groups/*.rb" ).each do |group|
    require group
end
