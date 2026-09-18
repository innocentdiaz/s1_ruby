# frozen_string_literal: true

module S1
  module Providers
    # Canned distributions, no network: the test double every consumer of the
    # gem needs, and the second implementation that proves the provider contract.
    #
    #   S1.configure { |c| c.provider = S1::Providers::Stub.new(escalate: 0.9, department: :billing) }
    #
    # Shorthand by question type, or the full fields:
    #   noul   -> 0.9              (probability, in 0..1)
    #   choice -> :billing         (that category at 1.0) | { choice:, probabilities:, confidence: }
    #   score  -> 2 or "Blocking"  (that level at 1.0: by position, by label or Scale[:label], or by the text shown)
    #                              | { legend:, probabilities:, confidence: }  (the expectation is derived)
    # A full-fields Hash is kept whole as the distribution's `raw`, so a `score:` or
    # `expectation:` in it is still there to read. A shorthand off the scale raises ValidationError. Unlisted questions get
    # neutral defaults: noul 0.5, first category, first level. A block receives
    # the Request and returns the same map.
    class Stub < Base
      def initialize(answers = {}, &block)
        super()
        @answers = answers.transform_keys(&:to_sym)
        @block = block
      end

      def call(request)
        canned = @answers.merge((@block&.call(request) || {}).transform_keys(&:to_sym))
        distributions = request.questions.to_h do |id, question|
          [id, distribution(id, question, **fields_for(id, question, canned[id]))]
        end
        build_result(distributions: distributions, model: "stub", usage: { input_tokens: 0, output_tokens: 0 })
      end

      private

      def fields_for(id, question, value)
        return { raw: value }.merge(value.transform_keys(&:to_sym)) if value.is_a?(Hash)

        case question
        when Question::Noul
          { probability: probability(id, value) }
        when Question::Choice
          pick = category(id, question, value)
          { choice: pick, probabilities: question.categories.to_h { |c| [c, c == pick ? 1.0 : 0.0] }, confidence: 1.0 }
        when Question::Score
          idx = level_index(id, question, value)
          legend = question.levels.each_with_index.to_h { |lvl, i| [i, lvl] }
          { legend: legend, probabilities: legend.keys.to_h { |i| [i.to_s, i == idx ? 1.0 : 0.0] }, confidence: 1.0 }
        end
      end

      def probability(id, value)
        return 0.5 if value.nil?

        probability = Float(value, exception: false)
        return probability if probability && (0.0..1.0).cover?(probability)

        raise ValidationError, "stub noul for #{id.inspect} is #{value.inspect}; the probability must be in 0.0..1.0"
      end

      def category(id, question, value)
        pick = (value || question.categories.first).to_s
        return pick if question.categories.include?(pick)

        raise ValidationError, "stub choice for #{id.inspect} is #{value.inspect}; must be one of #{question.categories}"
      end

      # By position (an Integer, or a Float with no fraction), by label (a String, a Level) or by the text shown.
      def level_index(id, question, value)
        return 0 if value.nil?
        unless value.is_a?(Numeric)
          return question.scale.labels.index(value.to_s) || question.levels.index(value.to_s) ||
                 raise(ValidationError, level_message(id, question, value))
        end

        range = 0...question.levels.size
        return value.to_i if value == value.to_i && range.cover?(value.to_i)

        raise ValidationError, "stub score for #{id.inspect} is #{value.inspect}; the level position must be in #{range}"
      end

      def level_message(id, question, value)
        shown = " (shown as #{question.levels})" if question.levels != question.scale.labels
        "stub score for #{id.inspect} is #{value.inspect}; must be one of #{question.scale.labels}#{shown}"
      end
    end
  end
end
