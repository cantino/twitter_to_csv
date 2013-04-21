# encoding: UTF-8

module TwitterToCsv
  class InvalidLogicError < StandardError; end

  class BoolWordFieldParser
    TOKEN_SEPARATOR = /[^a-zA-Z0-9-]+/

    def self.parse(string)
      parts = string.split(":")
      name = parts.shift
      tokens = parts.join(":").gsub(/\)/, " ) ").gsub(/\(/, " ( ").split(/\s+/).reject {|s| s.length == 0 }
      struct = []
      descend_parse(struct, tokens)
      { :name => name, :logic => struct }
    end

    def self.descend_parse(struct, tokens)
      while tokens.length > 0
        token = tokens.shift
        if token == ")"
          return
        elsif token == "("
          if struct.length > 0
            sub_struct = []
            struct << sub_struct
            descend_parse(sub_struct, tokens)
          end
        elsif %w[AND OR].include?(token)
          sub_struct = []
          struct << :and if token == "AND"
          struct << :or if token == "OR"
          struct << sub_struct
          descend_parse(sub_struct, tokens)
        else
          if struct[0]
            struct[0] += " " + token.downcase
          else
            struct << token.downcase
          end
        end
      end
    end

    def self.check(pattern, text)
      logic = pattern[:logic]
      tokens = text.downcase.split(TOKEN_SEPARATOR).reject {|t| t.length == 0 }.join(" ")
      !!descend_check(logic, tokens)
    end

    def self.descend_check(logic, tokens)
      if logic.is_a?(String)
        # See if the token(s) are present.
        tokens =~ /\b#{Regexp::escape logic}\b/
      elsif logic.length == 1
        # Recurse further.
        descend_check logic.first, tokens
      elsif logic.length == 3
        # Apply the given logical operation.
        first = descend_check(logic.first, tokens)
        last = descend_check(logic.last, tokens)
        if logic[1] == :and
          first && last
        elsif logic[1] == :or
          first || last
        else
          raise InvalidLogicError.new("Unknown operation: #{logic[1]}")
        end
      else
        raise InvalidLogicError.new("Invalid expression length of #{logic.length}")
      end
    end
  end
end
