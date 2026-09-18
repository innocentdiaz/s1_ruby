# frozen_string_literal: true

require_relative "s1/version"
require_relative "s1/errors"
require_relative "s1/config"
require_relative "s1/question"
require_relative "s1/collapsable"
require_relative "s1/scale"
require_relative "s1/level"
require_relative "s1/distribution"
require_relative "s1/answer"
require_relative "s1/result"
require_relative "s1/rendering"
require_relative "s1/metadata"
require_relative "s1/state"
require_relative "s1/predicate"
require_relative "s1/client"
require_relative "s1/primitives"
require_relative "s1/providers/base"
require_relative "s1/providers/stub"
require_relative "s1/providers/typesafe"
require_relative "s1/providers/cua"
require_relative "s1/providers/protocol"
require_relative "s1/conversion"

# S1 — Ruby for System One (S1) models. Evidence is prepared into a State,
# measured by a question into a distribution over a scale, and collapsed to a
# category (see THEORY.md).
#
#   S1.configure { |c| c.typesafe.api_key = ENV["TYPESAFE_API_KEY"] }
#
#   state = S1::State.new("I have asked three times. Can I talk to a real person?")
#   state.judge?("Is the customer asking for a human agent?")   # => true
#
#   result = state.measure do |q|
#     q.judge  :escalate,   "Is the customer asking for a human agent?"
#     q.choose :department, "Which team should handle this?", returns: "Refunds, exchanges", billing: "Charges"
#     q.score  :severity,   "How severe is the issue?", "Cosmetic", "Degraded", "Blocking"
#   end
#   result[:department].to_sym   # => :returns
module S1
  extend Client

  class << self
    def config
      @config ||= Config.new
    end

    def configure
      yield config
      Primitives.install!(config.primitives) if config.primitives
      Conversion.install!(config.psi_name)
      config
    end

    # Anything becomes an S1 State. Objects that know how (#to_s1: primitives,
    # typesafe-rails records) convert themselves. ψ(x) is this, when enabled.
    def to_state(evidence, **) = evidence.respond_to?(:to_s1) ? evidence.to_s1(**) : State.new(evidence, **)

    # A scale as a value: S1.scale("low", "mid", "high") is ordinal, S1.scale(a: "…", b: "…")
    # nominal, S1.scale(-> { … }) dynamic (see S1::Scale).
    def scale(...) = Scale.new(...)

    # Test hook: discard configuration between examples.
    def reset_config!
      @config = nil
    end
  end
end
