# frozen_string_literal: true

module S1
  # The three kinds of distribution, one per scale kind. `Answer` is the module's
  # historical name; `Answer::Base` is S1::Distribution.
  module Answer
    Base = Distribution

    # The dichotomous distribution — "noul" is its proper name. The probability
    # IS the signal: compares directly against numbers (`answer >= 0.85`), and
    # thresholds into a boolean via #true?. A threshold rides on it from birth —
    # the one it was measured under (the State's, else the config's as of the
    # measure, stamped by Client), or, built by hand, the config's as of its
    # construction; a later config change never reaches a noul that exists.
    class Noul < Distribution
      include Comparable

      attr_reader :probability, :threshold

      def initialize(id:, probability:, raw: nil, threshold: nil)
        @probability = probability.to_f
        @threshold = threshold || S1.config.threshold
        super(id: id, probabilities: { "true" => @probability,
                                       "false" => 1.0 - @probability }, confidence: nil, raw: raw)
      end

      def scale = [true, false]
      def with(threshold:) = Noul.new(id: id, probability: probability, raw: raw, threshold: threshold)

      def to_f = probability
      def to_s = probability.to_s
      def true?(threshold = self.threshold) = probability >= threshold
      def false?(threshold = self.threshold) = !true?(threshold)
      def <=>(other) = other.is_a?(Numeric) || other.is_a?(Noul) ? probability <=> other.to_f : nil
      def coerce(number) = [number.to_f, probability]

      # A noul has no separate confidence: distance from the threshold is it. Confident
      # at least `margin` away from the threshold, on either side — the complement of undecided?.
      # The positional is the margin, not a floor as on Distribution#confident?(at): a 0.85 noul
      # at threshold 0.5 is confident?(0.3) and not confident?(0.8). `decided?` is the same test
      # under the name that says so.
      def confident?(margin = 0.1, threshold: self.threshold) = !undecided?(margin, threshold: threshold)
      alias decided? confident?

      # The collapse, named: the probability becomes a boolean. `?` methods are
      # this same step (noul?, judge?, is?); keep the probability until here.
      def collapse(threshold = self.threshold) = true?(threshold)

      # `!answer` is "not true at the threshold", so `!!answer` is the collapse.
      # A bare `if answer` is still always truthy — Ruby's `if` never calls `!`.
      def ! = !collapse

      # Within `margin` of the threshold: too close to act on alone, hand off instead of collapsing.
      def undecided?(margin = 0.1, threshold: self.threshold) = (probability - threshold).abs < margin

      # Products of marginals: both / either / not. Exact only when the two properties are
      # independent given the state — the provider promises that no answer is context for
      # another, not that what they measure is independent. For overlapping properties ask
      # the conjunction as one question. The other operand is a noul or a number in 0..1 (a
      # marginal already known) — anything else (nil, a boolean) is an ArgumentError; the left
      # operand's threshold carries over.
      #   (r[:is_lead] & r[:qualified]) >= 0.8
      #   r[:is_lead] & 0.5
      #   ~r[:spam]
      def &(other) = Noul.new(id: :"#{id}&#{name_of(other)}", probability: probability * marginal(other), threshold: threshold)
      def |(other) = Noul.new(id: :"#{id}|#{name_of(other)}", probability: 1 - ((1 - probability) * (1 - marginal(other))), **carried)
      def ~ = Noul.new(id: :"~#{id}", probability: 1 - probability, threshold: threshold)

      private

      def name_of(other) = other.respond_to?(:id) ? other.id : other
      def carried = { threshold: threshold }

      def marginal(other)
        return other.to_f if other.is_a?(Noul) || (other.is_a?(Numeric) && (0..1).cover?(other))

        raise ArgumentError, "#{id.inspect}: the other operand must be a noul or a number in 0..1 (got #{other.inspect})"
      end
    end

    # The nominal distribution — mass over an unordered set of categories. It has
    # no proper name; the noun `choice` names the category picked, a Symbol,
    # which is the collapse: the most likely category by mass (the provider's
    # own pick only breaks a tie). Two choices are eql? when they name the same
    # category, so they bucket together under group_by.
    class Choice < Distribution
      attr_reader :choice

      # `scale` is the question's nominal S1::Scale: the classes are its categories and nothing else, so a
      # wire category off it raises (one the wire left out gets mass 0); with none (or a dynamic one) the
      # scale is built from the wire's.
      attr_reader :scale

      def initialize(id:, choice:, probabilities:, confidence:, raw: nil, scale: nil)
        mass = (probabilities || {}).to_h { |c, p| [c.to_s, p.to_f] }
        top = mass.values.max
        @choice = (top.nil? || mass[choice.to_s] == top ? choice : mass.key(top)).to_sym
        @scale = on_scale!(id, mass.keys | [@choice.to_s], scale) || Scale.new(mass.keys, ordered: false)
        super(id: id, probabilities: @scale.labels.to_h { |c| [c, 0.0] }.merge(mass), confidence: confidence, raw: raw)
      end

      # The categories as Symbols, in the scale's order.
      def categories = probabilities.keys.map(&:to_sym)
      alias options categories

      def to_sym = choice
      def to_s = choice.to_s
      def collapse(*) = choice
      # Every category as a Symbol, most likely first: a ranking from one call.
      def ranked = probabilities.sort_by { |_, p| -p }.map { |c, _| c.to_sym }
      def [](category) = probabilities[category.to_s]
      def ==(other) = other.respond_to?(:to_s) && to_s == other.to_s
      def eql?(other) = other.is_a?(Choice) && choice == other.choice
      def hash = choice.hash

      private

      def on_scale!(id, wire, scale)
        return if scale.nil? || scale.dynamic?

        stray = wire - scale.labels
        raise ValidationError, "#{id.to_sym.inspect}: #{stray.inspect} are not on #{scale.inspect}" if stray.any?

        scale
      end
    end

    # The ordinal distribution — mass over ordered levels. It has no proper name;
    # the noun `level` names the point on the scale, an S1::Level, which is the
    # collapse. `expectation` is the probability-weighted position (the expected
    # rank, the one interval-like number an ordinal distribution yields), always
    # derived from the mass — a provider's own number (`expectation:`, or the
    # wire's `score:`) is accepted and ignored; it survives only in `raw`. The
    # legend and the mass are re-keyed by rank on the legend's sorted keys
    # ("0", "1", … in the scale's order), whatever keys the wire used, so a
    # live measurement and its rehydration are the same object and a vendor's
    # keys survive only in `raw`; `key` is the most likely level's rank — its
    # `position`. A score needs mass on at least one level. Compares by
    # expectation, against a number or another score, so sort_by / max_by rank
    # the distributions.
    class Score < Distribution
      include Comparable

      # `scale` is the question's ordinal S1::Scale: the legend is its labels or its texts (the
      # definitions shown), else the wire answered another question and it raises; with none (or a
      # dynamic one) the scale is built from the legend.
      attr_reader :expectation, :scale

      alias score expectation

      def initialize(id:, legend:, probabilities:, confidence:, raw: nil, expectation: nil, score: nil, scale: nil) # rubocop:disable Lint/UnusedMethodArgument
        wire = legend.to_h.transform_keys { |k| k.to_s.to_i }
        mass = on_legend!(id.to_sym, wire, (probabilities || {}).to_h { |k, p| [k.to_s, p.to_f] })
        @legend, by_rank = ranked(wire, mass)
        @expectation = by_rank.sum { |k, p| k.to_i * p }.to_f
        asked = @legend.values.map(&:to_s)
        @scale = on_scale!(id, asked, scale) || Scale.new(asked)
        super(id: id, probabilities: by_rank, confidence: confidence, raw: raw)
      end

      def to_f = expectation
      def <=>(other) = other.is_a?(Numeric) || other.is_a?(Score) ? expectation <=> other.to_f : nil
      def coerce(number) = [number.to_f, expectation]
      def collapse(*) = level
      def to_s = "#{key} #{level.inspect}"

      # The rank of the most likely level — its `position` on the scale. `index` is the legacy
      # name; the legend key the wire used is in `raw`.
      def key = probabilities.max_by { |_, p| p }.first.to_i
      alias index key

      def level = scale.to_a[key]
      def levels = scale.to_a

      private

      attr_reader :legend

      def ranked(wire, mass)
        ranks = wire.keys.sort.each_with_index.to_h
        [wire.to_h { |k, text| [ranks[k], text] }.sort.to_h.freeze, mass.to_h { |k, p| [ranks[k.to_i].to_s, p] }]
      end

      def on_scale!(id, asked, scale)
        return if scale.nil? || scale.dynamic?
        return scale if [scale.labels, scale.texts].include?(asked)

        raise ValidationError, "#{id.to_sym.inspect}: the legend #{asked.inspect} is not #{scale.inspect}"
      end

      def on_legend!(id, wire, mass)
        stray = mass.keys.find { |k| !wire.key?(Integer(k, exception: false)) }
        raise ValidationError, "#{id.inspect}: probability for key #{stray.inspect} is outside the legend #{wire.keys}" if stray
        raise ValidationError, "#{id.inspect}: a score needs mass on at least one legend key" if mass.empty?

        mass
      end
    end
  end
end
