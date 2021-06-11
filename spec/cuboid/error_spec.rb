require 'spec_helper'

describe Cuboid::Error do
    it 'inherits from StandardError' do
        expect(Cuboid::Error <= StandardError).to be_truthy

        caught = false
        begin
            fail Cuboid::Error
        rescue StandardError => e
            caught = true
        end
        expect(caught).to be_truthy

        caught = false
        begin
            fail Cuboid::Error
        rescue
            caught = true
        end
        expect(caught).to be_truthy
    end
end
