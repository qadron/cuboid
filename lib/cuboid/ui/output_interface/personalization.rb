module Cuboid
module UI
module OutputInterface

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
module Personalization

    def included( base )
        base.extend ClassMethods
    end

    module ClassMethods
        def personalize_output!
            @personalize_output = true
        end

        def personalize_output?
            @personalize_output
        end
    end

    private

    def personalize_output( message )
        return message if !self.class.respond_to?( :personalize_output? )

        self.class.personalize_output? ?
            "#{self.class.name.split('::').last}: #{message}" : message
    end

    def output_root
        @output_root ||=
            File.expand_path( File.dirname( __FILE__ ) + '/../../../../' ) + '/'
    end

    def caller_location
        file = nil
        line = nil
        caller_method = nil
        Kernel.caller.each do |c|
            file, line, method = *c.scan( /(.*):(\d+):in `(?:.*\s)?(.*)'/ ).flatten
            next if file == output_provider_file

            caller_method = method
            break
        end

        file.gsub!( output_root, '' )

        context = nil
        if caller_method
            context = "[#{file}##{caller_method}:#{line}]"
        end

        context
    end

end

end
end
end
