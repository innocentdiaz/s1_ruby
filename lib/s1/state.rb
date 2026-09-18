# frozen_string_literal: true

module S1
  # The state: evidence prepared for judgement. A String, or a Hash/Array for
  # structured evidence — then instructions can point at fields with backticked
  # paths (`transcript`, `case_details.sol_deadline`, `messages[0].text`).
  # Rendering is fixed here, once (S1::Rendering): every question asked of a
  # State sees identical evidence.
  #
  #   state = S1::State.new(transcript)
  #   state.judge("Is the caller asking for a human agent?")             # => Answer::Noul, 0.94
  #   state.judge?("Is the caller asking for a human agent?")            # => true / false
  #   state.choose("Which team?", returns: "Refunds", billing: "Charges") # => Answer::Choice
  #   state.choice("Which team?", returns: "Refunds", billing: "Charges") # => :returns
  #   state.score("How severe?", "Cosmetic", "Degraded", "Blocking")      # => Answer::Score
  #   state.level("How severe?", "Cosmetic", "Degraded", "Blocking")      # => "Degraded"
  #
  # Each single-question method is one call. When several questions share the
  # state, measure them together — one call; each answered as if it were the only one:
  #
  #   result = state.measure do |q|
  #     q.judge  :escalate,   "Is the customer asking for a human agent?"
  #     q.choose :department, "Which team?", returns: "Refunds", billing: "Charges"
  #   end
  #   result[:department].to_sym
  #
  # The naming rule: a verb measures and returns the distribution; a noun
  # returns the thing it names; a `?` returns a boolean.
  #   verbs   judge, choose, score — one question each; measure — several at once
  #           (aliases of measure: ask, batch, ask_about)
  #   nouns   noul names the dichotomous distribution, so x.noul(q) == x.judge(q)
  #           choice names the category picked, so x.choice(q, …) == x.choose(q, …).collapse (a Symbol)
  #           level names the point on the ordinal scale, so x.level(q, *levels) == x.score(q, *levels).collapse (an S1::Level)
  #   ?       judge? (aliases noul?, ask?), is?, same_as? — booleans, judge(…).collapse(threshold)
  # The asymmetry is deliberate: only the dichotomous distribution has a proper
  # name (noul); nominal and ordinal distributions have none, so their nouns can
  # only name the category.
  #   is / is?              the English forms: "Is this …?"
  #   same_as / same_as?    "do these describe the same thing?"; === is the same, for case/when and grep
  #   given / against       the lens: the facts become `this`, the lens sits beside them, so a lens
  #                         keyed `this` (or `other`, on same_as) is refused — it would replace the facts
  # Aliases are plain Ruby `alias`es — a class's own method of the same name always wins.
  #
  # With `c.psi = true`, (ψ x) is State.new(x); ψ with no argument builds a
  # Predicate (see S1::Predicate) for select / group_by / sort_by / sum.
  #
  # Options (provider:, model:, timeout:, threshold:) override the global config
  # for this state; `given:` is the lens; anything else in **options rides along
  # on the Request for providers and on_result hooks (e.g. an owner to attribute cost to).
  #
  # Two keywords are reserved on every verb, measure included. `given:` is the
  # fluent form inline: x.choose("…", a: "A", given: { p: 1 }) is
  # x.given(p: 1).choose("…", a: "A"), and x.to_s1(given: { p: 1 }) is
  # x.given(p: 1). `threshold:` belongs to a collapse alone (judge?, is?,
  # same_as?); on a verb it is an ArgumentError, never a question option.
  class State
    RESERVED = %i[given threshold metadata].freeze
    THRESHOLD_ON_VERB = "threshold: only applies to a collapse (judge?, is?, same_as?)"

    # `facts` is the evidence as rendered, alone — what sits at `this` under a
    # lens; `lens` is the Hash beside it ({} with none); `rendered` is the whole.
    attr_reader :rendered, :options
    attr_accessor :facts, :lens

    alias state rendered
    alias evidence facts
    protected :facts=, :lens=

    def initialize(evidence, provider: nil, model: nil, timeout: nil, threshold: nil, given: nil, **options)
      raise ValidationError, "state can't be nil" if evidence.nil?

      @facts = Rendering.render(evidence)
      @lens = Rendering.render(given || {})
      State.lens!(@lens, :this)
      @rendered = @lens.empty? ? @facts : { this: @facts, **@lens }.freeze
      @provider = provider
      @model = model
      @timeout = timeout
      @threshold = threshold
      @options = Metadata.in(options).freeze
    end

    def threshold = @threshold || S1.config.threshold

    # A State is its own preparation: rendered once, reused for every question;
    # with options, the same rendering under them.
    def to_s1(**options) = options.empty? ? self : with(**options)

    # The same rendering with these per-state overrides; `given:` is the lens,
    # applied; anything else joins the options riding on the Request.
    def with(provider: @provider, model: @model, timeout: @timeout, threshold: @threshold, given: nil, **options)
      return self.given(**given).with(provider: provider, model: model, timeout: timeout, threshold: threshold, **options) if given

      merged = self.options.merge(Metadata.in(options)) { |key, old, new| key == :metadata ? old.merge(new) : new }
      dup.configure(provider: provider, model: model, timeout: timeout, threshold: threshold, options: merged)
    end

    # The same facts under a lens: the facts become `this`, the lens sits beside
    # them, and instructions can name either. A lens added to a lensed State
    # merges over it; the facts stay at `this`.
    #   (ψ transcript).given(preferences: prefs).is? "qualified, per `preferences`"
    def given(**lens)
      State.new(facts, given: self.lens.merge(Rendering.render(lens)), provider: @provider, model: @model, timeout: @timeout,
                       threshold: @threshold, **options)
    end
    alias against given

    # Several questions on one state, one call. Accepts a block, a Questions, or
    # a Hash; a Questions and a block together ask both. The nouls carry this
    # State's threshold, so the Result's collapse and true? use it. `given:`
    # is the fluent lens inline and `threshold:` an ArgumentError, as on every
    # verb; any other keyword is an id => Question pair.
    def measure(questions = nil, given: nil, metadata: nil, **inline, &)
      return with(metadata: metadata).measure(questions, given: given, **inline, &) if metadata
      return self.given(**given).measure(questions, **inline, &) if given
      raise ArgumentError, THRESHOLD_ON_VERB if inline.key?(:threshold)

      questions = questions.nil? ? inline : questions.to_h.merge(inline) if inline.any?
      S1.measure(self, Questions.coerce(questions, &), provider: @provider, model: @model, timeout: @timeout,
                                                       threshold: @threshold, **options)
    end
    alias ask measure
    alias batch measure
    alias ask_about measure

    def judge(instructions, criteria: nil, **clarification)
      reserved(:judge, instructions, criteria: criteria, **clarification) do
        ask_one(:noul) { |q| q.judge(:noul, instructions, criteria: criteria, **clarification) }
      end
    end
    alias noul judge

    def judge?(instructions, criteria: nil, threshold: nil, **clarification)
      judge(instructions, criteria: criteria, **clarification).collapse(*[threshold].compact)
    end
    alias noul? judge?
    alias ask? judge?

    # English-first judge: the phrase completes "Is this ...?".
    #   state.is?("a man's name")   state.is("asking for a human agent") >= 0.9
    # Only on State — never on String/Hash/Array, where `is?` would sit next to
    # equality methods.
    def is(phrase, **) = judge("Is this #{phrase}?", **)
    def is?(phrase, **) = judge?("Is this #{phrase}?", **)

    # Semantic equality, as a method rather than ==: (ψ "Acme Inc").same_as? "ACME, Incorporated"
    # An operator would run inside Hash#[], Array#include?, uniq — a network call in each.
    # The pair is `this` and `other`, with any lens beside them — so a lens keyed `other` is refused.
    def same_as(other, **clarification)
      reserved(:same_as, other, **clarification) do
        State.lens!(lens, :other)
        pair = State.new({ this: facts, other: S1.to_state(other).rendered, **lens },
                         provider: @provider, model: @model, timeout: @timeout, threshold: @threshold, **options)
        pair.judge("Do `this` and `other` describe the same thing?", **clarification)
      end
    end

    def same_as?(other, threshold: nil, **) = same_as(other, **).collapse(*[threshold].compact)

    # Case equality is Ruby's "does this match?" operator — Range, Regexp and Proc
    # define it, and only case/when, grep and any?(pattern) call it. So a State
    # in a `when` is a semantic match; == stays structural (Hash, uniq, RSpec).
    #   case vendor.name
    #   when (ψ "Acme Inc") then ...
    #   end
    #   names.grep(ψ "Acme Inc")
    def ===(other) = same_as?(other)

    NO_SCALE = "choose needs a scale: pass categories: (the facts are not candidates-shaped)"

    # `categories:` is the scale; `choices:` and `criteria:` (the wire word) are
    # accepted too, as are the categories inline as keywords. Choosing among the
    # evidence: when the facts are themselves the set of candidates — an Array of
    # Strings, or a Hash with String keys whose values are all nil or all Strings —
    # its labels are the scale, resolved before any lens so `given:` composes with
    # it. A Symbol-keyed Hash is a record, never candidates: it takes `categories:`.
    def choose(instructions, criteria: nil, categories: nil, choices: nil, **inline)
      criteria ||= categories || choices || (facts if inline.except(*RESERVED).empty? && categories_shaped?(facts))
      reserved(:choose, instructions, criteria: criteria, **inline) do
        raise ValidationError, NO_SCALE if criteria.nil? && inline.empty?

        ask_one(:choice) { |q| q.choose(:choice, instructions, criteria: criteria, **inline) }
      end
    end

    def choice(...) = choose(...).collapse

    def score(instructions, *levels, criteria: nil, **clarification)
      reserved(:score, instructions, *levels, criteria: criteria, **clarification) do
        ask_one(:score) { |q| q.score(:score, instructions, *levels, criteria: criteria, **clarification) }
      end
    end

    def level(...) = score(...).collapse

    # A lens sits beside the facts (`this`) or the pair (`this`, `other`); a key
    # of either name would replace them.
    def self.lens!(lens, key)
      return lens unless lens.keys.any? { |k| k.to_s == key.to_s }

      raise ValidationError, "#{key}: is the #{key == :this ? "facts'" : "comparand's"} key; name the lens something else"
    end

    protected

    def configure(provider:, model:, timeout:, threshold:, options:)
      @provider = provider
      @model = model
      @timeout = timeout
      @threshold = threshold
      @options = options.freeze
      self
    end

    private

    # Single-question calls use the scale kind's wire name as the id, so a Stub
    # keyed noul: / choice: / score: answers each kind.
    def ask_one(id, &) = measure(&)[id]

    # A verb's keywords are its definition (true:/false: on judge, the categories
    # on choose; score takes none), so the reserved ones are peeled here, before
    # the question sees them: `given:` re-enters the verb on the State under that
    # lens; `threshold:` never reaches a question. The block runs only when
    # neither was passed.
    def reserved(verb, *, **options)
      metadata = options.delete(:metadata)
      return with(metadata: metadata).public_send(verb, *, **options) if metadata

      lens = options.delete(:given)
      return given(**lens).public_send(verb, *, **options) if lens
      raise ArgumentError, THRESHOLD_ON_VERB if options.key?(:threshold)

      yield
    end

    def categories_shaped?(value)
      case value
      when Hash  then value.size >= 2 && value.keys.all?(String) && (value.values.all?(nil) || value.values.all?(String))
      when Array then value.size >= 2 && value.all?(String)
      else false
      end
    end
  end

  Subject = State
end
