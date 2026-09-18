# frozen_string_literal: true

module S1
  # A question not yet applied to a state, so it can go where Ruby expects a
  # block or a pattern. Built by ψ with no argument (or S1.predicates):
  #
  #   angry = ψ.is? "an angry customer"
  #   calls.select(&angry)                 calls.grep(angry)               calls.count(&angry)
  #   calls.group_by(&ψ.choice("Which team?", returns: "…", billing: "…"))   # => { returns: [...], ... }
  #   tickets.sort_by(&ψ.score("How severe?", "cosmetic", "degraded", "blocking"))
  #   calls.sum(&ψ.judge("the customer is angry"))                          # expected count, calibrated
  #
  # Define a question once, apply it to one or many:
  #   team = ψ.choice "Which team?", returns: "…", support: "…"
  #   team[ticket]  team.measure(ticket)  tickets.group_by(&team)
  #
  # Builders mirror State exactly, under the naming rule — a verb measures and
  # returns the distribution; a noun returns the thing it names; a `?` returns a
  # boolean: is/is?, judge/judge? (aliases noul/noul?, ask?), choose/choice,
  # score/level, same_as/same_as?. Each element is one call, and the rule holds
  # through Enumerable (call, [], to_proc, ===): a verb yields one distribution
  # per element (a noul sums as its probability, a score sorts by expectation,
  # a choice buckets by category), a noun the thing it names, a `?` a boolean.
  # `measure(x)` is always the distribution, whatever the name. A verb in a
  # boolean slot is always truthy — a distribution is never false — so select /
  # grep / count / find / partition take the `?` form, sum / sort_by the verb.
  # `given:` is the lens every element is judged against — the stream is the
  # evidence, `given:` is the lens:
  #
  #   qualified = ψ.is?("qualified for the role, per `qualifications`", given: { qualifications: role.requirements })
  #   candidates.select(&qualified)
  # Options split by side: `given:` and `as:` (a typesafe-rails form) shape
  # the state; everything else is the question's definition (`criteria:`, the wire word;
  # categories, enum)
  # or the collapse's (threshold, only on the `?` forms).
  STATE_OPTIONS = %i[given as].freeze
  # The verb behind each noun and `?`, so measure always yields the distribution.
  PREDICATE_VERB = { is?: :is, judge?: :judge, choice: :choose, level: :score, same_as?: :same_as }.freeze
  # The `?` forms: the only names a `threshold:` belongs to.
  COLLAPSES = %i[is? judge? same_as?].freeze

  Predicate = Data.define(:name, :args, :options) do
    # The verb applied to one state, un-collapsed: the distribution.
    def measure(evidence)
      state = options[:as] ? S1.to_state(evidence, as: options[:as]) : S1.to_state(evidence)
      state = state.given(**options[:given]) if options[:given]
      state.public_send(PREDICATE_VERB.fetch(name, name), *args, **question_options)
    end

    # Applied to one state, as Enumerable would: the distribution for a verb,
    # the collapsed value for a noun or a `?`.
    #   team = ψ.choice "Which team?", returns: "…", support: "…"
    #   team[ticket]               # => :returns      tickets.group_by(&team)
    def call(evidence)
      distribution = measure(evidence)
      PREDICATE_VERB.key?(name) ? distribution.collapse(*[options[:threshold]].compact) : distribution
    end
    alias_method :[], :call

    def to_proc = method(:call).to_proc
    def ===(evidence) = call(evidence)

    private

    # `threshold:` belongs to the collapse, so only a `?` carries it past the verb;
    # on a verb or a noun it reaches the State and raises there, as it does inline.
    def question_options = COLLAPSES.include?(name) ? options.except(*STATE_OPTIONS, :threshold) : options.except(*STATE_OPTIONS)
  end

  # Same rule as on a State: the verb (judge / choose / score) measures, the
  # noun names, the `?` collapses — through Enumerable too; `measure(x)` is
  # the distribution under any name.
  module Predicates
    extend self

    def is(phrase, **options) = Predicate.new(:is, [phrase], options)
    def is?(phrase, **options) = Predicate.new(:is?, [phrase], options)
    def judge(instructions, **options) = Predicate.new(:judge, [instructions], options)
    def judge?(instructions, **options) = Predicate.new(:judge?, [instructions], options)
    def choose(instructions, **options) = Predicate.new(:choose, [instructions], options)
    def choice(instructions, **options) = Predicate.new(:choice, [instructions], options)
    def score(instructions, *levels, **options) = Predicate.new(:score, [instructions, *levels], options)
    def level(instructions, *levels, **options) = Predicate.new(:level, [instructions, *levels], options)
    def same_as(other, **options) = Predicate.new(:same_as, [other], options)
    def same_as?(other, **options) = Predicate.new(:same_as?, [other], options)

    alias noul judge
    alias noul? judge?
    alias ask? judge?
  end

  def self.predicates = Predicates
end
