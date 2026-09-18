# frozen_string_literal: true

require "json"

module S1
  # The rendering: the function from evidence to state, applied once at
  # preparation. What comes out is a value, never a live reference — Strings
  # are copied, Hashes and Arrays rebuilt and frozen, everything else
  # snapshotted — so every question asked of a State sees identical evidence,
  # whatever the source does afterwards.
  module Rendering
    NOT_EVIDENCE = "is a measurement, not evidence; put its `collapse` or its `probabilities` in the lens"

    class << self
      # A String copies; a Hash keeps its keys and renders its values; an Array
      # or Set renders each element; scalars stand as they are; a Struct or Data
      # renders as its fields; anything that knows how to prepare itself (#to_s1)
      # contributes its own State's rendering; the rest is snapshotted as the
      # JSON the wire would carry. A measurement (a Distribution or a Result) is
      # not evidence and has no rendering: it is refused, not sent as its text.
      def render(value)
        case value
        when String                            then value.dup.freeze
        when Hash                              then value.to_h { |k, v| [k, render(v)] }.freeze
        when Array, Set                        then value.map { |v| render(v) }.freeze
        when Numeric, true, false, nil, Symbol then value
        when Distribution, Result              then raise ValidationError, "#{value.inspect} #{NOT_EVIDENCE}"
        else snapshot(value)
        end
      end

      private

      def snapshot(value)
        return value.to_s1.rendered if value.respond_to?(:to_s1)
        return render(value.to_h) if value.is_a?(Struct) || value.is_a?(Data)

        render(JSON.parse(JSON.generate(value)))
      end
    end
  end
end
