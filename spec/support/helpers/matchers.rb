RSpec::Matchers.define :be_same_array_as do |expected_array|
    match do |actual_array|
        Set.new(actual_array) == Set.new(expected_array)
    end
end
