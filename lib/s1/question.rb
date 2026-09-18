# frozen_string_literal: true

module S1
  # A question: a concept on a scale, with its working definition — immutable
  # value objects, one per scale kind. Provider-agnostic: #to_h is the wire
  # form every provider translates to its own format.
  #
  # `instructions` is the concept (the theory's word; `instructions` is the
  # code's): a String, or a Hash for structured questions (e.g. a `field` /
  # `extracted_value` / `question` verification). `criteria` is the working
  # definition of the scale, shaped differently per kind because it means
  # different things:
  #   Noul   — optional { true: "what counts as yes", false: "what counts as no" }
  #   Choice — { category => description | nil }  an UNORDERED set
  #   Score  — [level, level, ...]                 an ORDERED spectrum, worst -> best
  module Question
    Noul = Data.define(:instructions, :criteria) do
      def initialize(instructions:, criteria: nil)
        criteria = Question.normalize_noul_criteria(criteria)
        super(instructions: Question.check_instructions(instructions), criteria: criteria)
      end

      def type = "noul"
      def to_h = { type: type, instructions: instructions, criteria: criteria }.compact
    end

    Choice = Data.define(:instructions, :criteria) do
      # criteria: a nominal S1::Scale, { category => description }, or an Array of categories (no descriptions).
      def initialize(instructions:, criteria:)
        @scale = Question.scale_for("choice", criteria.is_a?(Scale) ? criteria : Question.choice_categories(criteria))
        raise ValidationError, "choice needs at least 2 options (got #{@scale.size})" if @scale.size < 2

        super(instructions: Question.check_instructions(instructions), criteria: @scale.definitions)
      end

      # The nominal S1::Scale; `criteria` is its wire form, { label => description }.
      attr_reader :scale

      def type = "choice"
      # The scale's labels, in wire order (Strings, as on the wire).
      def categories = criteria.keys
      alias_method :options, :categories
      def to_h = { type: type, instructions: instructions, criteria: criteria }
    end

    Score = Data.define(:instructions, :criteria) do
      # criteria: an ordinal S1::Scale (alone, or as the one element of the levels list), or the levels.
      def initialize(instructions:, criteria:)
        criteria = criteria.first if criteria.is_a?(Array) && criteria.one? && criteria.first.is_a?(Scale)
        if criteria.is_a?(Array) && criteria.any?(Scale)
          raise ValidationError, "score takes a scale or levels, not both (got #{criteria.inspect})"
        end

        @scale = Question.scale_for("score", criteria.is_a?(Scale) ? criteria : Array(criteria).map(&:to_s))
        raise ValidationError, "score needs at least 2 ordered levels (got #{@scale.size})" if @scale.size < 2

        super(instructions: Question.check_instructions(instructions), criteria: @scale.texts)
      end

      # The ordinal S1::Scale; `criteria` is its wire form — the levels in order, as shown: a
      # definition where the scale has one, else the label (the distribution speaks the labels).
      # The wire carries the texts alone, so `from_h(to_h)` of a described scale is a question
      # over the texts (`==` still holds: a question is its wire form); a caller that crosses a
      # boundary carries the labels itself (typesafe-rails: `Questions#stores`).
      attr_reader :scale

      def type = "score"
      def levels = criteria
      def to_h = { type: type, instructions: instructions, criteria: criteria }
    end

    class << self
      # Inverse of #to_h, for questions that crossed a serialization boundary
      # (a job queue, a database).
      def from_h(hash)
        h = hash.to_h.transform_keys(&:to_sym)
        klass = { "noul" => Noul, "choice" => Choice, "score" => Score }.fetch(h[:type].to_s) do
          raise ValidationError, "unknown question type #{h[:type].inspect}"
        end
        klass.new(instructions: h[:instructions], criteria: h[:criteria])
      end

      # The question's scale: the S1::Scale given, when its kind is the question's, else one
      # built from the wire form (the levels for a score, { label => description } for a choice).
      def scale_for(type, criteria)
        return Scale.new(criteria, ordered: type == "score") unless criteria.is_a?(Scale)

        wanted = type == "score" ? "an ordinal" : "a nominal"
        return criteria if criteria.kind == wanted.split.last

        raise ValidationError, "#{type} takes #{wanted} scale (got #{criteria.inspect})"
      end

      def check_instructions(instructions)
        case instructions
        when String then instructions.strip.tap do |s|
          raise ValidationError, "instructions can't be blank" if s.empty?
        end
        when Hash then instructions
        else raise ValidationError, "instructions must be a String or a Hash (got #{instructions.class})"
        end
      end

      # { category => description }, or a bare list of categories (no descriptions).
      def choice_categories(criteria)
        if criteria.is_a?(Array) && criteria.any?(Scale)
          raise ValidationError, "choose takes a scale or categories, not both (got #{criteria.inspect})"
        end

        criteria = criteria.to_h { |o| [o, nil] } if criteria.is_a?(Array) && criteria.none?(Hash)
        (criteria || {}).to_h.transform_keys(&:to_s)
      rescue TypeError, NoMethodError
        raise ValidationError, "choice options must be { option => description } or a list of options"
      end
      alias choice_options choice_categories

      def normalize_noul_criteria(criteria)
        return nil if criteria.nil? || criteria.empty?

        h = criteria.to_h.transform_keys(&:to_s)
        extra = h.keys - %w[true false]
        raise ValidationError, "noul criteria may only clarify true/false (got #{extra.inspect})" if extra.any?

        h
      end
    end
  end

  # The batch builder yielded by State#measure. Collects id => Question in
  # order, one method per scale kind, by the theory's verbs (judge / choose /
  # score; `noul`, the distribution's name, is judge's alias — there is no
  # `choice` here, a noun that would yield a distribution):
  #
  #   state.measure do |q|
  #     q.judge  :repeat,     "Contacted before?", true: "mentions a prior ticket", false: "no sign of one"
  #     q.choose :department, "Which team?", returns: "Refunds", billing: "Charges"
  #     q.score  :severity,   "How severe?", "Cosmetic", "Degraded", "Blocking"
  #   end
  #
  # The State's reserved keywords are refused here: the lens belongs to the
  # State (`state.given(…).measure { … }`, or `measure(given: …)`), the
  # threshold to a collapse; neither is part of a question's definition.
  class Questions
    include Enumerable

    RESERVED = "%s: belongs to the State, not a question (state.given(…).measure { … }; threshold on a collapse)"

    def initialize
      @questions = {}
    end

    def judge(id, instructions, criteria: nil, **clarification)
      reserved!(clarification)
      add(id, Question::Noul.new(instructions: instructions, criteria: criteria || clarification))
    end
    alias noul judge

    # categories: (or choices:, or criteria: — the wire word), or the categories inline as keywords.
    def choose(id, instructions, criteria: nil, categories: nil, choices: nil, **inline)
      reserved!(inline)
      add(id, Question::Choice.new(instructions: instructions, criteria: criteria || categories || choices || inline))
    end

    def score(id, instructions, *levels, criteria: nil, **reserved)
      reserved!(reserved)
      raise ArgumentError, "unknown keywords: #{reserved.keys.map(&:inspect).join(", ")}" if reserved.any?

      add(id, Question::Score.new(instructions: instructions, criteria: criteria || levels))
    end

    KINDS = [Question::Noul, Question::Choice, Question::Score].freeze

    # `question` is one of the three Question kinds; anything else — a
    # threshold, a model name, a bare String — is refused before the wire.
    def add(id, question)
      key = id.to_sym
      raise ValidationError, "duplicate question id #{key.inspect}" if @questions.key?(key)
      raise ValidationError, "#{key.inspect} is not a question (got #{question.inspect})" unless KINDS.any? { |k| question.is_a?(k) }

      @questions[key] = question
      self
    end

    def each(&) = @questions.each(&)
    def to_h = @questions.dup
    def size = @questions.size
    def empty? = @questions.empty?

    # Accepts a Questions, a Hash of id => Question, or a block — a block beside
    # either adds its questions to theirs. Always returns a frozen id => Question
    # map. `into` is the builder the block sees — a subclass can add sugar
    # (typesafe-rails fills choice options from enums).
    def self.coerce(questions = nil, into = new, &block)
      return questions.to_h.freeze if questions.is_a?(Questions) && !questions.empty? && block.nil?

      built = into
      (questions || {}).each { |id, q| built.add(id, q) }
      block&.call(built)
      raise ValidationError, "no questions given" if built.empty?

      built.to_h.freeze
    end

    private

    def reserved!(keywords)
      taken = keywords.keys & State::RESERVED
      raise ArgumentError, format(RESERVED, taken.first) if taken.any?
    end
  end
end
