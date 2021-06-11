class Array

    # @param    [#to_s, Array<#to_s>]  tags
    #
    # @return [Bool]
    #   `true` if `self` contains any of the `tags` when objects of both `self`
    #   and `tags` are converted to `String`.
    def includes_tags?( tags )
        return false if !tags

        tags = [tags].flatten.compact.map( &:to_s )
        return false if tags.empty?

        (self.flatten.compact.map( &:to_s ) & tags).any?
    end

end
