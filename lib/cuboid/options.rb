require 'yaml'
require 'singleton'

require_relative 'error'
require_relative 'utilities'

module Cuboid

# @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
# @see OptionGroups
class Options
    include Singleton

    def self.attr_accessor(*vars)
        @attr_accessors ||= []
        @attr_accessors |= vars
        super( *vars )
    end

    def self.attr_accessors
        @attr_accessors
    end

    def attr_accessors
        self.class.attr_accessors
    end

    # {Options} error namespace.
    #
    # All {Options} errors inherit from and live under it.
    #
    # @author Tasos "Zapotek" Laskos <tasos.laskos@gmail.com>
    class Error < Cuboid::Error
    end

    class <<self

        def method_missing( sym, *args, &block )
            if instance.respond_to?( sym )
                instance.send( sym, *args, &block )
            else
                super( sym, *args, &block )
            end
        end

        def respond_to?( *args )
            super || instance.respond_to?( *args )
        end

        # Ruby 2.0 doesn't like my class-level method_missing for some reason.
        # @private
        public :allocate

        # @return   [Hash<Symbol,OptionGroup>]
        #   {OptionGroups Option group} classes by name.
        def group_classes
            @group_classes ||= {}
        end

        # Should be called by {OptionGroup.inherited}.
        # @private
        def register_group( group )
            name = Utilities.caller_name

            # Prepare an attribute reader for this group...
            attr_reader name

            # ... and initialize it.
            instance_variable_set "@#{name}".to_sym, group.new

            group_classes[name.to_sym] = group
        end
    end

    # Load all {OptionGroups}.
    require_relative 'option_groups'

    TO_RPC_IGNORE = Set.new([
        :instance, :rpc, :agent, :queue, :paths,
        :snapshot, :report, :output, :system
    ])

    TO_HASH_IGNORE = Set.new([ :instance ])


    # @return    [String]
    #   E-mail address of the person that authorized the run.
    #
    # @see HTTP::Client#headers
    attr_accessor :authorized_by

    attr_accessor :application

    def initialize
        reset
    end

    # Restores everything to their default values.
    #
    # @return [Options] `self`
    def reset
        # nil everything out.
        instance_variables.each { |var| instance_variable_set( var.to_s, nil ) }

        # Set fresh option groups.
        group_classes.each do |name, klass|
            instance_variable_set "@#{name}".to_sym, klass.new
        end

        @authorized_by  = nil

        self
    end


    # Configures options via a Hash object.
    #
    # @param    [Hash]  options
    #   If the key refers to a class attribute, the attribute will be assigned
    #   the given value, if it refers to one of the {OptionGroups} the value
    #   should be a hash with data to update that {OptionGroup group} using
    #   {OptionGroup#update}.
    #
    # @return   [Options]
    #
    # @see OptionGroups
    def update( options )
        options.each do |k, v|
            k = k.to_sym
            if group_classes.include? k
                send( k ).update v
            else
                send( "#{k.to_s}=", v )
            end
        end

        self
    end
    alias :set :update

    # @return   [Hash]
    #   Hash of errors with the name of the invalid options/groups as the keys.
    def validate
        errors = {}
        group_classes.keys.each do |name|
            next if (group_errors = send(name).validate).empty?
            errors[name] = group_errors
        end
        errors
    end

    # @param    [String]    file
    #   Saves `self` to `file` using YAML.
    def save( file )
        File.open( file, 'w' ) do |f|
            f.write to_save_data
            f.path
        end
    end

    def to_save_data
        to_rpc_data.to_yaml
    end

    def to_save_data_without_defaults
        to_rpc_data_without_defaults.to_yaml
    end

    # Loads a file created by {#save}.
    #
    # @param    [String]    filepath
    #   Path to the file created by {#save}.
    #
    # @return   [Cuboid::Options]
    def load( filepath )
        update( YAML.load_file( filepath ) )
    end

    # @return    [Hash]
    #   `self` converted to a Hash suitable for RPC transmission.
    def to_rpc_data
        hash = {}
        instance_variables.each do |var|
            val = instance_variable_get( var )
            var = normalize_name( var )

            next if TO_RPC_IGNORE.include?( var )

            hash[var.to_s] = (val.is_a? OptionGroup) ? val.to_rpc_data : val
        end
        hash.deep_clone
    end

    def to_rpc_data_without_defaults
        defaults = self.class.allocate.reset.to_rpc_data
        to_rpc_data.reject { |k, v| defaults[k] == v }
    end

    # @return    [Hash]
    #   `self` converted to a Hash.
    def to_hash
        hash = {}
        instance_variables.each do |var|
            val = instance_variable_get( var )
            var = normalize_name( var )

            next if TO_HASH_IGNORE.include?( var )

            hash[var] = (val.is_a? OptionGroup) ? val.to_h : val
        end

        hash.deep_clone
    end
    alias :to_h :to_hash

    # @param    [Hash]  hash
    #   Hash to convert into {#to_hash} format.
    #
    # @return   [Hash]
    #   `hash` in {#to_hash} format.
    def rpc_data_to_hash( hash )
        self.class.allocate.reset.update( hash ).to_hash.
            reject { |k| TO_RPC_IGNORE.include? k }
    end

    # @param    [Hash]  hash
    #   Hash to convert into {#to_rpc_data} format.
    #
    # @return   [Hash]
    #   `hash` in {#to_rpc_data} format.
    def hash_to_rpc_data( hash )
        self.class.allocate.reset.update( hash ).to_rpc_data
    end

    def hash_to_save_data( hash )
        self.class.allocate.reset.update( hash ).to_save_data
    end

    def dup
        self.class.allocate.reset.update( self.to_h )
    end

    private

    def group_classes
        self.class.group_classes
    end

    def normalize_name( name )
        name.to_s.gsub( '@', '' ).to_sym
    end

end
end
