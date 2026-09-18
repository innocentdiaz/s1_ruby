# frozen_string_literal: true

module S1
  # The distribution: the product of a judgement — mass over every category of
  # the scale, all at once, plus the provider's own confidence where the scale
  # has one. Normalized: consumers read these and never a provider's wire keys,
  # which is what lets a second provider slot in unchanged. One subclass per
  # scale kind (Answer::Noul, Answer::Choice, Answer::Score); each is a
  # Collapsable and names its own collapse.
  class Distribution
    include Collapsable

    # `probabilities` is the masses, keyed by wire category.
    attr_reader :id, :probabilities, :confidence, :raw

    def initialize(id:, probabilities:, confidence:, raw: nil)
      @id = id.to_sym
      @probabilities = (probabilities || {}).transform_keys(&:to_s).freeze
      @confidence = confidence
      @raw = raw
      freeze
    end

    # The S1::Scale the judgement was measured over ([true, false] for a noul); `to_a` is the categories in the scale's own type.
    def scale
      raise NotImplementedError, "#{self.class}#scale"
    end

    # Confidence ≥ at: act automatically at or above `at`, escalate below it. True when the
    # provider reports none — read `confidence` to escalate those. Carries nothing the masses
    # do not: jev derives it from the distribution's shape, cua reports the winning mass.
    def confident?(at) = confidence.nil? || confidence >= at

    # `type` is the wire name of the scale kind (noul / choice / score); `kind` is the theory's word for it.
    def type = self.class.name.split("::").last.downcase
    alias kind type

    def inspect = "#<#{self.class.name} #{self}>"
  end
end
