module Cuboid
module Support
module Mixins

module Profiler

    @@on = false

    class <<self

        def included( base )
            base.extend ClassMethods
        end

        def enable!
            @@on = true
        end

        def disable!
            @@on = false
        end

        def on?
            @@on
        end

        def results
            h = {}
            ObjectSpace.each_object( Class ) do |klass|
                next if !klass.included_modules.include? self
                next if klass.profile_data.empty?

                h[klass] = {
                    sorted_total: klass.profile_data_total,
                    sorted_avg:   klass.profile_data_avg
                }
            end
            h
        end

    end

    module ClassMethods

        def profile_data
            @profile ||= {}
        end

        def profile_data_avg
            ::Hash[self.profile_data.sort_by { |_, d| d[:avg] }.reverse]
        end

        def profile_data_total
            ::Hash[self.profile_data.sort_by { |_, d| d[:total] }.reverse]
        end

    end

    def profile_proc( *args, &block )
        return block.call( *args ) if !Support::Mixins::Profiler.on?

        profile_wrap_proc( &block ).call *args
    end

    def profile_wrap_proc( &block )
        return block if !Support::Mixins::Profiler.on?

        proc do |*args|
            t = Time.now
            r = block.call( *args )

            loc = block.source_location.join( ':' )
            loc.gsub!( Options.paths.root, '' )

            data = self.class.profile_data[loc] ||= {
                total: 0,
                count: 0,
                avg:   0
            }

            data[:total] += Time.now - t
            data[:count] += 1
            data[:avg]    = data[:total] / data[:count]

            r
        end
    end

end

end
end
end
