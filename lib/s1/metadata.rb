# frozen_string_literal: true

module S1
  # `metadata:` labels a measurement for the program — cost ledgers, logs, traces — and is
  # never sent to the model or the provider. It rides on the Request as `request.metadata`,
  # keys symbolized; a later `with(metadata:)` or a verb's merges over it. It travels in
  # background jobs and logs, so it holds JSON's values only, checked when it is set.
  module Metadata
    VALUES = "metadata holds strings, numbers, booleans, nil, and arrays or hashes of them"

    extend self

    # `options` with its :metadata checked and its keys symbolized, when it has one.
    def in(options)
      return options unless options.key?(:metadata)

      options.merge(metadata: check!(options[:metadata]))
    end

    def check!(value, path = "metadata")
      raise ValidationError, "#{path}: is a Hash (got #{value.inspect})" unless value.nil? || value.is_a?(Hash)

      value.to_h.to_h do |key, v|
        raise ValidationError, "#{path} keys are Strings or Symbols (got #{key.inspect})" unless key.is_a?(String) || key.is_a?(Symbol)

        [key.to_sym, value!(v, "#{path}[#{key.inspect}]")]
      end.freeze
    end

    def value!(value, path)
      case value
      when nil, true, false, String, Symbol, Integer, Float then value
      when Array then value.map { |v| value!(v, path) }
      when Hash then check!(value, path)
      else raise ValidationError, "#{path} is a #{value.class}; #{VALUES}"
      end
    end
  end
end
