class Hash
    def stringify_keys
        h = self.map do |k,v|
            v_str = if v.instance_of? Hash
                        v.stringify_keys
                    else
                        v
                    end

            [k.to_s, v_str]
        end
        Hash[h]
    end

    def symbolize_keys
        h = self.map do |k,v|
            v_sym = if v.instance_of? Hash
                        v.symbolize_keys
                    else
                        v
                    end

            [k.to_sym, v_sym]
        end
        Hash[h]
    end
end
