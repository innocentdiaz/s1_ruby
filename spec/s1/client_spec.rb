# frozen_string_literal: true

RSpec.describe S1::Client do
  let(:questions) { { yes: S1::Question::Noul.new(instructions: "Yes?") } }

  it "measures a State as its rendering, never as the object" do
    seen = nil
    S1.config.provider = S1::Providers::Stub.new { |req| seen = req and { yes: 0.7 } }
    S1.measure(S1::State.new("hello"), questions)
    expect(seen.state).to eq("hello")
    S1.measure(S1::State.new({ a: 1 }).given(p: 2), questions)
    expect(seen.state).to eq(this: { a: 1 }, p: 2)
    expect(JSON.generate(seen.state)).not_to include("S1::State")
  end

  it "renders bare evidence once, into a value: the Request never carries a live reference" do
    seen = nil
    S1.config.provider = S1::Providers::Stub.new { |req| seen = req and { yes: 0.7 } }
    tags = Set["a"]
    evidence = { at: Time.at(0).utc, tags: tags, text: +"t" }
    S1.measure(evidence, questions)
    tags << "b"
    evidence[:text] << "!"
    expect(seen.state).to eq(at: Time.at(0).utc.to_s, tags: ["a"], text: "t")
    expect(seen.state).to be_frozen
    expect(seen.state).to eq(S1::State.new({ at: Time.at(0).utc, tags: Set["a"], text: "t" }).rendered)
  end

  describe ".resolve_provider" do
    it "resolves a symbol to a Providers class" do
      expect(S1.resolve_provider(:stub)).to be_a(S1::Providers::Stub)
      expect(S1.resolve_provider("typesafe")).to be_a(S1::Providers::TypeSafe)
      expect(S1.resolve_provider(:type_safe)).to be_a(S1::Providers::TypeSafe)
    end

    it "returns an instance that responds to #call as is" do
      callable = ->(_request) { :called }
      expect(S1.resolve_provider(callable)).to be(callable)
      instance = S1::Providers::Stub.new
      expect(S1.resolve_provider(instance)).to be(instance)
    end

    it "falls back to the configured provider" do
      S1.config.provider = :stub
      expect(S1.resolve_provider).to be_a(S1::Providers::Stub)
      expect(S1.reset_config!).to be_nil
      expect(S1.resolve_provider).to be_a(S1::Providers::TypeSafe)
    end

    it "builds a named provider from its config section" do
      S1.config.typesafe.base_url = "http://localhost:8000"
      S1.config.typesafe.api_key = "sk-test"
      stub = stub_request(:post, "http://localhost:8000/v1/systemone")
             .with(headers: { "Authorization" => "Bearer sk-test" })
             .to_return(status: 200, body: JSON.generate(answers: { yes: { noul: 0.7 } }))
      expect(S1.measure("text", questions, provider: :typesafe)[:yes].to_f).to eq(0.7)
      expect(stub).to have_been_requested.once
    end

    it "raises InvalidRequestError for an unknown name" do
      expect { S1.resolve_provider(:nope) }
        .to raise_error(S1::InvalidRequestError, "unknown S1 provider: :nope")
      expect { S1.resolve_provider("not a const") }.to raise_error(S1::InvalidRequestError)
    end
  end

  describe ".measure" do
    it "accepts a bare callable as the provider, with no capability check" do
      distributions = { e: S1::Answer::Noul.new(id: :e, probability: 0.9) }
      provider = ->(_req) { S1::Result.new(distributions: distributions, provider: :lambda) }
      expect(S1.measure("x", { e: S1::Question::Noul.new(instructions: "q?") }, provider: provider)[:e].to_f).to eq(0.9)
    end

    it "routes through the named provider" do
      result = S1.measure("text", questions, provider: :stub)
      expect(result).to be_a(S1::Result)
      expect(result.provider).to eq(:stub)
      expect(result[:yes].to_f).to eq(0.5)
    end

    it "routes through a provider instance" do
      result = S1.measure("text", questions, provider: S1::Providers::Stub.new(yes: 0.8))
      expect(result[:yes].to_f).to eq(0.8)
    end

    it "uses the configured provider by default" do
      S1.config.provider = S1::Providers::Stub.new(yes: 0.7)
      expect(S1.measure("text", questions)[:yes].to_f).to eq(0.7)
    end

    it "coerces a block-built Questions and a Hash alike" do
      built = S1::Questions.new
      built.judge(:yes, "Yes?")
      expect(S1.measure("text", built, provider: :stub).distributions.keys).to eq([:yes])
    end

    it "is S1.measure, with S1.ask as its alias" do
      expect(S1.ask("text", questions, provider: :stub)[:yes].to_f).to eq(0.5)
      expect(S1.method(:ask)).to eq(S1.method(:measure))
    end

    it "defaults timeout from config, leaves model to the provider, and overrides both per call" do
      requests = []
      S1.on_result { |_result, request| requests << request }
      S1.config.timeout = 12

      S1.measure("text", questions, provider: :stub)
      S1.measure("text", questions, provider: :stub, model: "jev-fast", timeout: 1)

      expect(requests.map(&:model)).to eq([nil, "jev-fast"])
      expect(requests.map(&:timeout)).to eq([12, 1])
    end

    it "passes extra options on the Request" do
      captured = nil
      S1.on_result { |_result, request| captured = request }
      S1.measure("text", questions, provider: :stub, owner: "firm-1")
      expect(captured.options).to eq(owner: "firm-1")
      expect(captured.state).to eq("text")
      expect(captured.questions).to eq(questions)
    end

    it "sets duration_ms on the result" do
      result = S1.measure("text", questions, provider: :stub)
      expect(result.duration_ms).to be_a(Integer)
      expect(result.duration_ms).to be >= 0
    end
  end

  describe "hooks" do
    it "calls every on_result hook with the timed result and the request" do
      seen = []
      first = S1.on_result { |result, request| seen << [:first, result, request] }
      S1.on_result { |result, request| seen << [:second, result, request] }

      returned = S1.measure("text", questions, provider: :stub)

      expect(first).to be_a(Proc)
      expect(seen.map(&:first)).to eq(%i[first second])
      expect(seen.map { |s| s[1] }).to all(be(returned))
      expect(seen.first[1].duration_ms).to be_a(Integer)
      expect(seen.first[2]).to be_a(S1::Request)
      expect(seen.first[2].questions).to eq(questions)
    end

    it "clears hooks with clear_hooks!" do
      calls = 0
      S1.on_result { calls += 1 }
      S1.clear_hooks!
      S1.measure("text", questions, provider: :stub)
      expect(calls).to eq(0)
      expect(S1.hooks).to eq([])
    end
  end

  describe "threshold:" do
    it "stamps every noul with it, and leaves the rest alone" do
      S1.config.provider = S1::Providers::Stub.new(a: 0.7, b: 0.2, which: :x)
      questions = S1::Questions.new.judge(:a, "?").judge(:b, "?").choose(:which, "?", x: "X", y: "Y")
      result = S1.measure("text", questions, threshold: 0.9)
      expect(result.distributions.values_at(:a, :b).map(&:threshold)).to eq([0.9, 0.9])
      expect(result.to_h).to eq(a: false, b: false, which: :x)
      expect(S1.measure("text", questions)[:a].threshold).to eq(0.5)
      expect(S1.measure("text", questions).to_h).to eq(a: true, b: false, which: :x)
    end

    it "stamps the config's threshold when none is given, so the measurement keeps the threshold it was taken under" do
      S1.config.provider = S1::Providers::Stub.new(a: 0.7, which: :x)
      questions = S1::Questions.new.judge(:a, "?").choose(:which, "?", x: "X", y: "Y")
      result = S1.measure("text", questions)
      expect(result[:a].instance_variable_get(:@threshold)).to eq(0.5)
      S1.config.threshold = 0.95
      expect(result[:a].threshold).to eq(0.5)
      expect(result.threshold).to eq(0.5)
      expect(result.collapse).to eq(a: true, which: :x)
      expect(result.to_h).to eq(a: true, which: :x)
      expect(result.true?(:a)).to be(true)
      expect(!!result[:a]).to be(true) # rubocop:disable Style/DoubleNegation
      other = S1::Answer::Noul.new(id: :o, probability: 0.5)
      expect((result[:a] & other).threshold).to eq(0.5)
      expect((result[:a] | other).threshold).to eq(0.5)
      expect((~result[:a]).threshold).to eq(0.5)
      expect(S1.measure("text", questions)[:a].threshold).to eq(0.95)
    end
  end
end
