# frozen_string_literal: true

module S1
  # A batch of distributions from one measure, plus telemetry (usage, model,
  # provider, duration_ms, raw). `distributions` (a frozen Hash, keyed by
  # question id) is the enumeration, and the Result enumerates it as
  # [id, distribution] pairs. Pattern-matches (#deconstruct_keys): nouls
  # as booleans, choices as symbols, scores as Levels — which match integer
  # ranges and labels alike:
  # `case result in { escalate: true, severity: 2.. }`, `in { severity: "Blocking" }`.
  class Result
    include Enumerable
    include Collapsable

    attr_reader :distributions, :usage, :model, :provider, :duration_ms, :raw

    alias answers distributions

    # `threshold:` stamps every noul with that threshold; nil leaves each noul at the one it
    # carries (only #with_threshold(nil) re-stamps the config's).
    def initialize(distributions: nil, answers: nil, usage: {}, model: nil, provider: nil, duration_ms: nil, raw: nil,
                   threshold: nil)
      raise ArgumentError, "missing keyword: :distributions" if distributions.nil? && answers.nil?

      @distributions = (distributions || answers).to_h.transform_keys(&:to_sym)
      @distributions = @distributions.transform_values { |d| d.is_a?(Answer::Noul) ? d.with(threshold: threshold) : d } if threshold
      @distributions.freeze
      @usage = (usage || {}).transform_keys(&:to_sym).freeze
      @model = model
      @provider = provider
      @duration_ms = duration_ms
      @raw = raw
      freeze
    end

    # Every distribution collapsed at once: nouls as booleans (each at its own
    # threshold, unless one is passed), choices as symbols, scores as Levels.
    # `to_h` is the same; pattern matching sees this view, so integer ranges and
    # labels both work as patterns:
    #   case state.measure { |q| ... }
    #   in { escalate: true, severity: 2.. }   then page_someone
    #   in { severity: "Blocking" }            then ...
    #   in { department: :billing }            then ...
    #   end
    def collapse(threshold = nil)
      distributions.transform_values { |d| threshold ? d.collapse(threshold) : d.collapse }
    end
    alias to_h collapse

    def deconstruct_keys(keys) = keys ? collapse.slice(*keys.map(&:to_sym)) : collapse

    def [](id)
      distributions.fetch(id.to_sym) { raise KeyError, "no answer for #{id.inspect} (have #{distributions.keys.inspect})" }
    end

    def key?(id) = distributions.key?(id.to_sym)
    def each(&) = distributions.each(&)
    def size = distributions.size

    # The distributions of one kind, by id.
    def nouls   = distributions.select { |_, d| d.is_a?(Answer::Noul) }
    def choices = distributions.select { |_, d| d.is_a?(Answer::Choice) }
    def scores  = distributions.select { |_, d| d.is_a?(Answer::Score) }

    def true?(id, threshold = nil)
      noul = self[id]
      raise ValidationError, "#{id.inspect} is a #{noul.type}, not a noul" unless noul.is_a?(Answer::Noul)

      threshold ? noul.true?(threshold) : noul.true?
    end

    def input_tokens  = usage[:input_tokens].to_i
    def output_tokens = usage[:output_tokens].to_i

    # The threshold every noul here was measured under; nil when they differ or there is no noul.
    def threshold
      thresholds = distributions.values.grep(Answer::Noul).map(&:threshold).uniq
      thresholds.first if thresholds.one?
    end

    def with(**changes)
      changes[:distributions] = changes.delete(:answers) if changes.key?(:answers)
      self.class.new(distributions: distributions, usage: usage, model: model, provider: provider, duration_ms: duration_ms,
                     raw: raw, **changes)
    end

    # The same distributions with every noul measured under `threshold`; with nil each is
    # rebuilt, and Noul.new stamps the config's value as of now — so a cached Result served
    # to a threshold-less State carries the config's threshold at serve time, not whatever
    # the config says at collapse.
    def with_threshold(threshold)
      with(distributions: distributions.transform_values { |d| d.is_a?(Answer::Noul) ? d.with(threshold: threshold) : d })
    end
  end

  # What a provider receives: the state, the id => Question map, and options.
  Request = Data.define(:state, :questions, :model, :timeout, :options) do
    def initialize(state:, questions:, model: nil, timeout: nil, options: {})
      super(state: state, questions: questions, model: model, timeout: timeout, options: options.freeze)
    end

    # The caller's labels for this measurement (State#with(metadata:)); {} when none.
    def metadata = options[:metadata] || {}
  end
end
