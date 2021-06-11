class Hash

    if !method_defined?( :to_h )
        alias :to_h :to_hash
    end

    # Converts the hash keys to strings.
    #
    # @param    [Boolean]    recursively
    #   Go through the Hash recursively?
    #
    # @return [Hash]
    #   Hash with +self+'s keys recursively converted to strings.
    def my_stringify_keys( recursively = true )
        stringified = {}
        each do |k, v|
            stringified[k.to_s] = (recursively && v.is_a?( Hash ) ?
                v.my_stringify_keys : v)
        end
        stringified
    end

    # Converts the hash keys to symbols.
    #
    # @param    [Boolean]    recursively
    #   Go through the Hash recursively?
    #
    # @return [Hash]
    #   Hash with +self+'s keys recursively converted to symbols.
    def my_symbolize_keys( recursively = true )
        symbolize = {}
        each do |k, v|
            k = k.respond_to?(:to_sym) ? k.to_sym : k

            symbolize[k] = (recursively && v.is_a?( Hash ) ?
                v.my_symbolize_keys : v)
        end
        symbolize
    end

end
