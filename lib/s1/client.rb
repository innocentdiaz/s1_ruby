# frozen_string_literal: true

module S1
  # One measure, end to end: builds the Request from a state and its questions,
  # resolves the provider, refuses question kinds it cannot answer, times the
  # call, stamps the threshold the measurement was taken under on the nouls (the
  # caller's, forwarded by Result#with_threshold; else the config's now, stamped
  # by Noul.new when none is given — never read at collapse), and hands the Result
  # to every on_result hook. State and Questions are the ways of reaching this;
  # Providers are what it calls.
  module Client
    # `state` is a State, or evidence rendered here so the Request carries a
    # value and never a live reference; `threshold:` is the caller's collapse
    # threshold; it rides on the nouls, not the Request.
    def measure(state, questions, provider: nil, model: nil, timeout: nil, threshold: nil, **options)
      request = Request.new(
        state: state.is_a?(State) ? state.rendered : Rendering.render(state),
        questions: Questions.coerce(questions),
        model: model,
        timeout: timeout || S1.config.timeout,
        options: options
      )
      impl = resolve_provider(provider)
      request.questions.each do |id, q| # a bare callable answers everything; Providers::Base declares
        next unless impl.respond_to?(:supports?) && !impl.supports?(q)

        raise UnsupportedError, "#{impl.name} cannot answer a #{q.type} (#{id.inspect})"
      end
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = impl.call(request).with_threshold(threshold)
      result = result.with(duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round)
      hooks.each { |hook| hook.call(result, request) }
      result
    end
    alias ask measure

    # Evidence prepared: S1.state(x) is S1::State.new(x).
    def state(evidence, **) = State.new(evidence, **)

    # A provider is an object responding to #call(Request) -> Result. Pass an
    # instance, or a name that resolves under Providers (:typesafe -> Providers::TypeSafe),
    # built with its section of the config. No registry to maintain.
    def resolve_provider(provider = nil)
      provider ||= S1.config.provider
      return provider if provider.respond_to?(:call)

      wanted = provider.to_s.delete("_").downcase
      const = Providers.constants.find { |c| c.to_s.downcase == wanted } or
        raise InvalidRequestError, "unknown S1 provider: #{provider.inspect}"
      klass = Providers.const_get(const, false)
      klass.new(**S1.config.section(klass.settings_name))
    end

    # Observe every completed call — telemetry, cost ledgers, logging — without
    # the gem knowing anything about where that goes.
    #   S1.on_result { |result, request| record(result.usage, request.options[:owner]) }
    def on_result(&block)
      hooks << block
      block
    end

    def hooks = (@hooks ||= [])
    def clear_hooks! = @hooks = []
  end
end
