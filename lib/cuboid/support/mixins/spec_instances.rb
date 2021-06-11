module Cuboid
module Support
module Mixins

# @note Only for when running specs!
#
# Keeps track of every initialized instance so that they can be properly
# cleaned-up later.
module SpecInstances

    def self.prepended( base )
        base.extend ClassMethods
    end

    module ClassMethods

        # @abstract
        def _spec_instance_cleanup( i )
            fail 'Not implemented.'
        end

        def _spec_instances_cleanup
            _spec_instances.each do |i|
                _spec_instance_cleanup i
            end

            _spec_instances_clear
        end

        def _spec_instances_clear
            _spec_instances.clear
        end

        def _spec_instance( instance )
            return if !_spec_instances_collect?
            _spec_instances << instance
        end

        def _spec_instances_collect!
            @_spec_instances_collect = true
        end

        def _spec_instances_collect?
            @_spec_instances_collect
        end

        private

        def _spec_instances
            @_spec_instances ||= Concurrent::Array.new
        end

    end

    def initialize(*)
        super

        self.class._spec_instance self
    end

end

end
end
end
