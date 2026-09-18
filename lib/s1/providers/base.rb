# frozen_string_literal: true

module S1
  module Providers
    # The provider contract: #call(Request) -> Result. A provider owns its
    # transport and its wire format, and translates into the normalized
    # distributions here — consumers never see a vendor's keys.
    class Base
      class << self
        attr_reader :settings_name

        # Declares the provider's section of S1.config, with defaults; a callable
        # default is evaluated when the Config is built. The section is what
        # Client.resolve_provider passes to .new when the provider is named.
        #   settings :typesafe, api_key: -> { ENV.fetch("TYPESAFE_API_KEY", nil) }, model: "jev-latest"
        def settings(name = nil, **defaults)
          @settings_name = (name || self.name.split("::").last.downcase).to_sym
          S1::Config.register(@settings_name, defaults)
        end
      end

      def call(_request)
        raise NotImplementedError, "#{self.class}#call(request) must return a S1::Result"
      end

      def name = self.class.name.split("::").last.downcase.to_sym

      # Whether this provider answers a question of that kind. Client.measure
      # checks before calling; a choice-only model (cua-s1-forms) overrides it
      # as `question.is_a?(Question::Choice)`.
      def supports?(_question) = true

      protected

      def build_result(distributions: nil, answers: nil, model: nil, usage: {}, raw: nil)
        Result.new(distributions: distributions || answers, usage: usage, model: model, provider: name, raw: raw)
      end

      # The normalizer: one distribution of the kind the question's scale
      # demands, so every provider builds the same objects from its own wire fields.
      # A score's expectation is derived from its masses; a wire `score:` (or `expectation:`) is ignored here
      # and survives only in whatever `raw:` the provider passes (SystemOneHTTP the answer hash, the Stub its given hash).
      def distribution(id, question, raw: nil, **fields)
        case question
        when Question::Noul
          Answer::Noul.new(id: id, probability: fields.fetch(:probability), raw: raw)
        when Question::Choice
          Answer::Choice.new(id: id, choice: fields.fetch(:choice), probabilities: fields.fetch(:probabilities),
                             confidence: fields[:confidence], raw: raw, scale: question.scale)
        when Question::Score
          Answer::Score.new(id: id, legend: fields.fetch(:legend), probabilities: fields.fetch(:probabilities),
                            confidence: fields[:confidence], raw: raw, scale: question.scale)
        else
          raise ValidationError, "unknown question type #{question.class}"
        end
      end
      alias answer distribution
    end
  end
end
