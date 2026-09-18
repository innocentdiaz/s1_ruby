# frozen_string_literal: true

RSpec.describe S1::State do
  let(:stub) { S1::Providers::Stub.new(noul: 0.9) }

  before { S1.config.provider = stub }

  it "is also S1::Subject" do
    expect(S1::Subject).to be(described_class)
    expect(S1::Subject.new("x")).to be_a(described_class)
  end

  describe "rendering is fixed at prepare" do
    it "copies a String, so the source can change and the state does not" do
      text = +"before"
      state = described_class.new(text)
      text << " and after"
      expect(state.rendered).to eq("before")
      expect(state.rendered).to be_frozen
      expect(state.state).to be(state.rendered)
    end

    it "rebuilds a Hash and an Array, nested, and freezes every level" do
      source = { transcript: +"hi", messages: [{ text: +"one" }, +"two"], n: 1, ok: true, tag: :x, none: nil }
      state = described_class.new(source)
      source[:transcript] << "!"
      source[:messages][0][:text] << "!"
      source[:messages] << "three"
      source[:extra] = 1
      expect(state.rendered).to eq(transcript: "hi", messages: [{ text: "one" }, "two"], n: 1, ok: true, tag: :x, none: nil)
      expect(state.rendered).to be_frozen
      expect(state.rendered[:transcript]).to be_frozen
      expect(state.rendered[:messages]).to be_frozen
      expect(state.rendered[:messages][0]).to be_frozen
      expect(state.rendered[:messages][0][:text]).to be_frozen
      expect(state.rendered.keys).to eq(%i[transcript messages n ok tag none])
    end

    it "renders anything that prepares itself through its own State, and snapshots the rest as the wire would see it" do
      prepared = Class.new { def to_s1(**) = S1::State.new({ name: "converted" }) }.new
      opaque = Object.new
      state = described_class.new([prepared, opaque, 2.5])
      expect(state.rendered).to eq([{ name: "converted" }, opaque.to_s, 2.5])
      expect(described_class.new(described_class.new("inner")).rendered).to eq("inner")
      expect(S1::Rendering.render("s")).to be_frozen
    end

    it "snapshots a Set, a Struct, a Data and a mutable object, so a later mutation never reaches the state" do
      tags = Set["a"]
      point = Struct.new(:x).new(+"1")
      pair = Data.define(:l, :r).new(l: +"L", r: 2)
      json = Class.new { def to_json(*) = %({"seen":"then"}) }.new
      state = described_class.new({ tags: tags, point: point, pair: pair, json: json })
      tags << "b"
      point.x << "!"
      expect(state.rendered).to eq(tags: ["a"], point: { x: "1" }, pair: { l: "L", r: 2 }, json: { "seen" => "then" })
      expect(state.rendered[:tags]).to be_frozen
      expect(state.rendered[:point]).to be_frozen
      expect(state.rendered[:point][:x]).to be_frozen
      expect(state.rendered[:pair]).to be_frozen
      expect(JSON.generate(state.rendered)).to eq('{"tags":["a"],"point":{"x":"1"},"pair":{"l":"L","r":2},"json":{"seen":"then"}}')
    end

    it "renders the lens too" do
      prefs = { min: +"2" }
      state = described_class.new("call").given(prefs: prefs)
      prefs[:min] << "0"
      expect(state.rendered).to eq(this: "call", prefs: { min: "2" })
      expect(state.rendered[:prefs]).to be_frozen
    end

    it "refuses a measurement as evidence — a distribution or a Result has no rendering; its collapse or probabilities do" do
      noul = S1::Answer::Noul.new(id: :prior, probability: 0.9)
      message = "#<S1::Answer::Noul 0.9> is a measurement, not evidence; put its `collapse` or its `probabilities` in the lens"
      expect { described_class.new("t", given: { prior: noul }) }.to raise_error(S1::ValidationError, message)
      expect { described_class.new({ prior: noul }) }.to raise_error(S1::ValidationError, message)
      expect { described_class.new([noul]) }.to raise_error(S1::ValidationError, message)
      result = S1::State.new("t", provider: S1::Providers::Stub.new(a: 0.9)).measure { |q| q.judge :a, "?" }
      expect { described_class.new("t").given(prior: result) }
        .to raise_error(S1::ValidationError, /S1::Result.* is a measurement, not evidence/)
      expect(described_class.new("t", given: { prior: noul.collapse, mass: noul.probabilities }).rendered)
        .to eq(this: "t", prior: true, mass: { "true" => 0.9, "false" => 0.09999999999999998 })
    end
  end

  it "rejects a nil state" do
    expect { described_class.new(nil) }.to raise_error(S1::ValidationError, /nil/)
  end

  it "exposes the rendered state and options" do
    state = described_class.new({ transcript: "hi" }, owner: "firm-1")
    expect(state.rendered).to eq(transcript: "hi")
    expect(state.state).to eq(transcript: "hi")
    expect(state.options).to eq(owner: "firm-1")
    expect(state.options).to be_frozen
  end

  describe "#judge" do
    it "returns an Answer::Noul with id :noul" do
      noul = described_class.new("text").judge("Is it?")
      expect(noul).to be_a(S1::Answer::Noul)
      expect(noul).to be_a(S1::Distribution)
      expect(noul.id).to eq(:noul)
      expect(noul.to_f).to eq(0.9)
    end

    it "is what the noun noul names: the dichotomous distribution itself" do
      state = described_class.new("text")
      expect(state.noul("Is it?")).to be_a(S1::Answer::Noul)
      expect(state.noul("Is it?").to_f).to eq(state.judge("Is it?").to_f)
    end

    it "sends clarification as criteria" do
      captured = nil
      S1.on_result { |_result, request| captured = request }
      described_class.new("text").judge("Before?", true: "ticket", false: "none")
      expect(captured.questions[:noul].criteria).to eq("true" => "ticket", "false" => "none")
    end
  end

  describe "#judge?" do
    it "phrases #is / #is? as a question" do
      asked = nil
      S1.config.provider = S1::Providers::Stub.new { |req| asked = req.questions[:noul].instructions and { noul: 0.9 } }
      expect(described_class.new("Michael").is?("a man's name")).to be(true)
      expect(asked).to eq("Is this a man's name?")
      expect(described_class.new("Michael").is("a man's name").to_f).to eq(0.9)
      expect(described_class.instance_method(:is).parameters).to include(%i[req phrase])
      expect(described_class.instance_method(:is?).parameters).to include(%i[req phrase])
      expect(S1::Predicates.method(:is).parameters).to include(%i[req phrase])
      expect(S1::Predicates.method(:is?).parameters).to include(%i[req phrase])
    end

    it "asks whether two states describe the same thing with #same_as?" do
      seen = nil
      S1.config.provider = S1::Providers::Stub.new { |req| seen = req and { noul: 0.95 } }
      expect(described_class.new("Acme Inc", owner: :me).same_as?("ACME, Incorporated")).to be(true)
      expect(seen.state).to eq(this: "Acme Inc", other: "ACME, Incorporated")
      expect(seen.options[:owner]).to eq(:me)
      expect(described_class.new("Acme Inc").same_as?("Acme", threshold: 0.99)).to be(false)
      expect(described_class.new("Acme Inc").same_as("Acme").to_f).to eq(0.95)
    end

    it "matches semantically with ===, and only there" do
      S1.config.provider = S1::Providers::Stub.new { |req| { noul: req.state[:other].start_with?("ACME") ? 0.95 : 0.05 } }
      acme = described_class.new("Acme Inc")
      candidate = "ACME, Incorporated"
      matched = case candidate
                when acme then :same
                else :different
                end
      expect(matched).to eq(:same)
      expect(["ACME Corp", "Beaver Dam"].grep(acme)).to eq(["ACME Corp"])
      expect(acme == "ACME, Incorporated").to be(false)
      expect([acme, acme].uniq.size).to eq(1)
    end

    it "judges under a lens with #given" do
      seen = nil
      S1.config.provider = S1::Providers::Stub.new { |req| seen = req and { noul: 0.9 } }
      expect(described_class.new("call", owner: :me).given(prefs: { min: 2 }).is?("qualified per `prefs`")).to be(true)
      expect(seen.state).to eq(this: "call", prefs: { min: 2 })
      expect(seen.questions[:noul].instructions).to eq("Is this qualified per `prefs`?")
      expect(seen.options[:owner]).to eq(:me)
      expect(described_class.new("call").against(prefs: 1).rendered).to eq(this: "call", prefs: 1)
    end

    it "composes lenses: a second given merges beside the facts, and the facts stay at this" do
      seen = nil
      S1.config.provider = S1::Providers::Stub.new { |req| seen = req.state and { noul: 0.9 } }
      twice = described_class.new("t", owner: :me).given(policy: "P").given(region: "R")
      expect(twice.rendered).to eq(this: "t", policy: "P", region: "R")
      expect(twice.facts).to eq("t")
      expect(twice.lens).to eq(policy: "P", region: "R")
      expect(twice.options).to eq(owner: :me)
      expect(described_class.new("t").given(policy: "P").given(policy: "Q").rendered).to eq(this: "t", policy: "Q")
      expect(described_class.new("t").given(a: 1).judge("?", given: { b: 2 })).to be_a(S1::Answer::Noul)
      expect(seen).to eq(this: "t", a: 1, b: 2)
      expect(described_class.new("t").lens).to eq({})
      expect(described_class.new("t").lens).to be_frozen
    end

    it "keeps the lens beside the pair in same_as, fluent, inline, and through a predicate" do
      seen = nil
      S1.config.provider = S1::Providers::Stub.new { |req| seen = req.state and { noul: 0.9 } }
      described_class.new("Acme").given(aliases: ["ACME Inc"]).same_as("ACME Inc")
      expect(seen).to eq(this: "Acme", other: "ACME Inc", aliases: ["ACME Inc"])
      described_class.new("Acme").same_as?("ACME Inc", given: { aliases: ["ACME Inc"] })
      expect(seen).to eq(this: "Acme", other: "ACME Inc", aliases: ["ACME Inc"])
      S1.predicates.same_as?("z", given: { r: 1 })["Acme"]
      expect(seen).to eq(this: "Acme", other: "z", r: 1)
      described_class.new("Acme").given(a: 1).given(b: 2).same_as("z")
      expect(seen).to eq(this: "Acme", other: "z", a: 1, b: 2)
    end

    it "names the facts: the rendered evidence alone, what sits at this — evidence is its alias" do
      at = Time.at(0).utc
      state = described_class.new({ at: at })
      expect(state.facts).to eq(at: at.to_s)
      expect(state.facts).to be(state.rendered)
      expect(state.evidence).to be(state.facts)
      lensed = state.given(p: 1)
      expect(lensed.facts).to eq(at: at.to_s)
      expect(lensed.rendered).to eq(this: { at: at.to_s }, p: 1)
    end

    it "measures several questions under #measure, and its aliases ask / batch / ask_about" do
      S1.config.provider = S1::Providers::Stub.new(e: 0.9)
      expect(described_class.new("x").measure { |q| q.judge :e, "q?" }.true?(:e)).to be(true)
      expect(described_class.new("x").ask { |q| q.judge :e, "q?" }.true?(:e)).to be(true)
      expect(described_class.new("x").batch { |q| q.judge :e, "q?" }.true?(:e)).to be(true)
      expect(described_class.new("x").ask_about { |q| q.judge :e, "q?" }.true?(:e)).to be(true)
    end

    it "is also #ask? and #noul?" do
      S1.config.provider = S1::Providers::Stub.new(noul: 0.8)
      expect(described_class.new("x").ask?("q?")).to be(true)
      expect(described_class.new("x").noul?("q?")).to be(true)
      expect(described_class.new("x").judge?("q?")).to be(true)
      expect(described_class.new("x").judge("q?").to_f).to eq(0.8)
    end

    it "takes a per-call threshold" do
      S1.config.provider = S1::Providers::Stub.new(noul: 0.8)
      expect(described_class.new("x").judge?("q?", threshold: 0.9)).to be(false)
      expect(described_class.new("x").judge?("q?", threshold: 0.7)).to be(true)
    end

    it "thresholds at the global threshold" do
      expect(described_class.new("text").judge?("Is it?")).to be(true)
      S1.config.threshold = 0.95
      expect(described_class.new("text").judge?("Is it?")).to be(false)
    end

    it "thresholds at a per-State override" do
      expect(described_class.new("text", threshold: 0.95).judge?("Is it?")).to be(false)
      expect(described_class.new("text", threshold: 0.5).judge?("Is it?")).to be(true)
      expect(described_class.new("text", threshold: 0.95).threshold).to eq(0.95)
      expect(described_class.new("text").threshold).to eq(0.5)
    end

    it "keeps the per-State threshold through given / against and same_as" do
      strict = described_class.new("text", threshold: 0.95)
      expect(strict.given(p: 1).threshold).to eq(0.95)
      expect(strict.against(p: 1).judge?("Is it?")).to be(false)
      expect(strict.given(p: 1).is?("it")).to be(false)
      expect(strict.same_as?("text")).to be(false)
      expect(strict.given(p: 1).same_as?("text")).to be(false)
      expect(described_class.new("text", threshold: 0.5).given(p: 1).same_as?("text")).to be(true)
      expect(strict.same_as?("text", threshold: 0.5)).to be(true)
      expect(strict.given(p: 1).measure { |q| q.judge :a, "?" }.true?(:a)).to be(false)
    end

    it "stamps the per-State threshold on every noul, so to_h / true? / patterns collapse at it" do
      S1.config.provider = S1::Providers::Stub.new(a: 0.7)
      result = described_class.new("x", threshold: 0.9).measure { |q| q.judge :a, "?" }
      expect(result[:a].threshold).to eq(0.9)
      expect(result.to_h[:a]).to be(false)
      expect(result.collapse).to eq(a: false)
      expect(result.true?(:a)).to be(false)
      expect(result.true?(:a, 0.6)).to be(true)
      expect(result.collapse(0.6)).to eq(a: true)
      expect((result in { a: false })).to be(true)
      expect(described_class.new("x").measure { |q| q.judge :a, "?" }[:a].threshold).to eq(0.5)
      expect(described_class.new("x").measure { |q| q.judge :a, "?" }.to_h[:a]).to be(true)
    end

    it "measures a single judge under the per-State threshold" do
      S1.config.provider = S1::Providers::Stub.new(noul: 0.7)
      noul = described_class.new("x", threshold: 0.9).judge("?")
      expect(noul.threshold).to eq(0.9)
      expect(noul.true?).to be(false)
      expect(!!noul).to be(false) # rubocop:disable Style/DoubleNegation
      expect(noul.collapse).to be(false)
      expect(noul.collapse(0.6)).to be(true)
      expect((noul & noul).threshold).to eq(0.9)
      S1.config.threshold = 0.6
      expect(described_class.new("x").judge("?").true?).to be(true)
    end
  end

  describe "the reserved keywords" do
    let(:requests) { [] }

    before { S1.config.provider = S1::Providers::Stub.new { |req| requests << req and { noul: 0.9, choice: :b, score: 1 } } }

    it "routes given: on any verb through #given" do
      subject_ = described_class.new("x", owner: :me)
      expect(subject_.choose("q?", a: "A", b: "B", given: { p: 1 }).to_sym).to eq(:b)
      expect(requests.last.state).to eq(this: "x", p: 1)
      expect(requests.last.questions[:choice].categories).to eq(%w[a b])
      expect(requests.last.options).to eq(owner: :me)

      subject_.judge("q?", true: "t", given: { p: 2 })
      expect(requests.last.state).to eq(this: "x", p: 2)
      expect(requests.last.questions[:noul].criteria).to eq("true" => "t")
      subject_.judge?("q?", given: { p: 3 })
      expect(requests.last.state).to eq(this: "x", p: 3)
      subject_.is("it", given: { p: 4 })
      subject_.is?("it", given: { p: 5 })
      expect(requests.last(2).map { |r| r.state[:p] }).to eq([4, 5])
      subject_.choice("q?", a: "A", b: "B", given: { p: 6 })
      expect(requests.last.state).to eq(this: "x", p: 6)
      expect(subject_.score("q?", "low", "high", given: { p: 7 }).level).to eq("high")
      expect(requests.last.state).to eq(this: "x", p: 7)
      expect(requests.last.questions[:score].levels).to eq(%w[low high])
      subject_.level("q?", "low", "high", given: { p: 8 })
      expect(requests.last.state).to eq(this: "x", p: 8)
      subject_.same_as("y", given: { p: 9 })
      expect(requests.last.state).to eq(this: "x", other: "y", p: 9)
      subject_.same_as?("y", given: { p: 10 })
      expect(requests.last.state).to eq(this: "x", other: "y", p: 10)
      subject_.measure(given: { p: 11 }) { |q| q.judge :a, "?" }
      expect(requests.last.state).to eq(this: "x", p: 11)
      expect(requests.last.options).to eq(owner: :me)
    end

    it "takes given: at prepare, as the lens: State.new(x, given: …) is State.new(x).given(…)" do
      state = described_class.new("x", given: { p: 1 }, owner: :me)
      expect(state.rendered).to eq(this: "x", p: 1)
      expect(state.facts).to eq("x")
      expect(state.lens).to eq(p: 1)
      expect(state.options).to eq(owner: :me)
      expect(state.rendered).to eq(described_class.new("x").given(p: 1).rendered)
      expect(described_class.new("x", given: {}).rendered).to eq("x")
    end

    it "refuses threshold: on measure and its aliases, as on every verb, before any question is built" do
      %i[measure ask batch ask_about].each do |verb|
        expect { described_class.new("x").public_send(verb, threshold: 0.9) { |q| q.judge :a, "q?" } }
          .to raise_error(ArgumentError, "threshold: only applies to a collapse (judge?, is?, same_as?)"), verb.to_s
      end
      expect { described_class.new("x").measure(given: { p: 1 }, threshold: 0.9) { |q| q.judge :a, "q?" } }
        .to raise_error(ArgumentError, /threshold: only applies to a collapse/)
      expect(requests).to be_empty
    end

    it "refuses any non-Question inline pair — a model name, a bare String — before the wire" do
      expect { described_class.new("x").measure(model: "m") { |q| q.judge :a, "q?" } }
        .to raise_error(S1::ValidationError, /:model is not a question \(got "m"\)/)
      expect { described_class.new("x").measure(a: "q?") }.to raise_error(S1::ValidationError, /:a is not a question/)
      expect { S1::Questions.new.add(:t, 0.9) }.to raise_error(S1::ValidationError, /:t is not a question \(got 0.9\)/)
      expect(requests).to be_empty
    end

    it "applies given: through #with, #to_s1 and S1.to_state on a State, as on evidence" do
      state = described_class.new("x", owner: :me)
      expect(state.to_s1(given: { a: 1 }).rendered).to eq(this: "x", a: 1)
      expect(state.to_s1(given: { a: 1 }).lens).to eq(a: 1)
      expect(state.with(given: { a: 1 }, threshold: 0.9).rendered).to eq(this: "x", a: 1)
      expect(state.with(given: { a: 1 }, threshold: 0.9).threshold).to eq(0.9)
      expect(state.with(given: { a: 1 }).options).to eq(owner: :me)
      expect(S1.to_state(state, given: { a: 1 }).rendered).to eq(this: "x", a: 1)
      expect(S1.to_state(state, given: { a: 1 }).options).to eq(owner: :me)
      expect(state.given(b: 2).to_s1(given: { a: 1 }).rendered).to eq(this: "x", b: 2, a: 1)
      state.to_s1(given: { a: 1 }).judge("q?")
      expect(requests.last.state).to eq(this: "x", a: 1)
      expect(requests.last.options).to eq(owner: :me)
    end

    it "refuses a lens keyed this, or other on same_as: the facts and the pair keep their keys" do
      expect { described_class.new("x", given: { this: "y" }) }.to raise_error(S1::ValidationError, /this: is the facts' key/)
      expect { described_class.new("x").given(this: "y") }.to raise_error(S1::ValidationError, /this: is the facts' key/)
      expect { described_class.new("x").given("this" => "y") }.to raise_error(S1::ValidationError, /this: is the facts' key/)
      expect { described_class.new("x").judge("q?", given: { this: "y" }) }.to raise_error(S1::ValidationError, /this:/)
      expect { described_class.new("x").given(other: "z").same_as("w") }
        .to raise_error(S1::ValidationError, /other: is the comparand's key/)
      expect { described_class.new("x").same_as?("w", given: { other: "z" }) }.to raise_error(S1::ValidationError, /other:/)
      expect(described_class.new("x").given(other: "z").judge("q?")).to be_a(S1::Answer::Noul)
      expect(requests.last.state).to eq(this: "x", other: "z")
      expect(requests.size).to eq(1)
    end

    it "hands the State itself to the Client, so the Request carries the very rendering" do
      state = described_class.new({ a: "x", b: [1, { c: "z" }] })
      state.judge("q?")
      expect(requests.last.state).to be(state.rendered)
      state.measure { |q| q.judge :a, "q?" }
      expect(requests.last.state).to be(state.rendered)
    end

    it "refuses given: and threshold: as a batch question's keywords: the lens belongs to the State" do
      questions = S1::Questions.new
      expect { questions.choose :c, "?", a: nil, b: nil, given: { p: 1 } }.to raise_error(ArgumentError, /given: belongs to the State/)
      expect { questions.judge :j, "?", given: { p: 1 } }.to raise_error(ArgumentError, /given: belongs to the State/)
      expect { questions.score :s, "?", "lo", "hi", given: { p: 1 } }.to raise_error(ArgumentError, /given: belongs to the State/)
      expect { questions.choose :c, "?", a: nil, b: nil, threshold: 0.2 }.to raise_error(ArgumentError, /threshold: belongs to the State/)
      expect { questions.score :s, "?", "lo", "hi", foo: 1 }.to raise_error(ArgumentError, /unknown keywords: :foo/)
      expect(questions).to be_empty
      expect { described_class.new("x").measure { |q| q.choose :c, "?", a: nil, given: { p: 1 } } }.to raise_error(ArgumentError, /given:/)
      expect(requests).to be_empty
    end

    it "is the same call as the fluent form" do
      subject_ = described_class.new("x")
      subject_.choose("q?", a: "A", b: "B", given: { p: 1 })
      subject_.given(p: 1).choose("q?", a: "A", b: "B")
      inline, fluent = requests.last(2)
      expect(inline.state).to eq(fluent.state)
      expect(inline.questions).to eq(fluent.questions)
      expect(inline.options).to eq(fluent.options)
    end

    it "accepts threshold: only where it collapses" do
      subject_ = described_class.new("x")
      message = "threshold: only applies to a collapse (judge?, is?, same_as?)"
      expect(subject_.judge?("q?", threshold: 0.95)).to be(false)
      expect(subject_.is?("it", threshold: 0.95)).to be(false)
      expect(subject_.same_as?("y", threshold: 0.95)).to be(false)
      expect(subject_.judge?("q?", threshold: 0.95, given: { p: 1 })).to be(false)
      %i[judge noul is choose choice score level same_as].each do |verb|
        args, kw = case verb
                   when :choose, :choice then [["q?"], { a: "A", b: "B", threshold: 0.9 }]
                   when :score, :level then [["q?", "low", "high"], { threshold: 0.9 }]
                   else [["q?"], { threshold: 0.9 }]
                   end
        expect { subject_.public_send(verb, *args, **kw) }.to raise_error(ArgumentError, message), verb.to_s
      end
      expect(requests.map { |r| r.questions.values.map(&:to_h) }.flatten).not_to include(a_hash_including(threshold: 0.9))
    end
  end

  describe "the naming rule: a verb measures and returns the distribution; a noun returns the thing it names; a ? a boolean" do
    before { S1.config.provider = S1::Providers::Stub.new(noul: 0.9, choice: :b, score: 2) }

    let(:subject_) { described_class.new("x") }

    it "judge → Noul, noul → the same Noul, judge? → boolean" do
      expect(subject_.judge("q?")).to be_a(S1::Answer::Noul)
      expect(subject_.noul("q?")).to be_a(S1::Answer::Noul)
      expect(subject_.noul("q?").to_f).to eq(subject_.judge("q?").to_f)
      expect(subject_.judge?("q?")).to be(true)
    end

    it "choose → Choice, choice → the option" do
      expect(subject_.choose("q?", a: "1", b: "2")).to be_a(S1::Answer::Choice)
      expect(subject_.choice("q?", a: "1", b: "2")).to eq(:b)
    end

    it "score → Score, level → the level, an S1::Level" do
      expect(subject_.score("q?", "low", "mid", "high")).to be_a(S1::Answer::Score)
      expect(subject_.level("q?", "low", "mid", "high")).to eq("high")
      expect(subject_.level("q?", "low", "mid", "high")).to be_a(S1::Level)
    end

    it "takes a Scale wherever a list or a hash of categories went, and the answer carries that very scale" do
      severity = S1.scale("low", "mid", "high", name: "Severity")
      team = S1.scale(a: "1", b: "2")
      expect(subject_.score("q?", severity).scale).to be(severity)
      expect(subject_.level("q?", severity).scale).to be(severity)
      expect(subject_.level("q?", severity)).to eq(severity[:high])
      expect(subject_.level("q?", severity).high?).to be(true)
      expect(subject_.choose("q?", categories: team).scale).to be(team)
      expect(subject_.choose("q?", criteria: team).scale).to be(team)
      expect(subject_.choice("q?", categories: team)).to eq(team[:b])
      expect(S1.predicates.level("q?", severity)["x"].scale).to be(severity)
      expect(S1.predicates.choice("q?", categories: team)["x"]).to be(:b)
      expect { subject_.score("q?", team) }.to raise_error(S1::ValidationError, /score takes an ordinal scale/)
      expect { subject_.choose("q?", categories: severity) }.to raise_error(S1::ValidationError, /choice takes a nominal scale/)
      result = subject_.measure { |q| q.score(:score, "q?", severity).choose(:choice, "q?", categories: team) }
      expect(result[:score].scale).to be(severity)
      expect(result[:choice].scale).to be(team)
      case result
      in { score: ^(severity.fetch(:high)) => lvl, choice: Symbol => sym }
        expect(lvl).to eq("high")
        expect(sym).to be(:b)
      end
    end

    it "holds as the identity: choice and level are the verb collapsed; the ? is the noul collapsed" do
      expect(subject_.judge?("q?")).to eq(subject_.judge("q?").collapse)
      expect(subject_.judge?("q?", threshold: 0.95)).to eq(subject_.judge("q?").collapse(0.95))
      expect(subject_.choice("q?", a: "1", b: "2")).to eq(subject_.choose("q?", a: "1", b: "2").collapse)
      expect(subject_.level("q?", "low", "mid", "high")).to eq(subject_.score("q?", "low", "mid", "high").collapse)
    end

    it "holds for predicates: measure gives the distribution; through Enumerable the verb stays a distribution" do
      p = S1.predicates
      expect(p.choose("q?", a: "1", b: "2").measure("x")).to be_a(S1::Answer::Choice)
      expect(p.choice("q?", a: "1", b: "2").measure("x")).to be_a(S1::Answer::Choice)
      expect(p.choice("q?", a: "1", b: "2")["x"]).to be(:b)
      expect(p.level("q?", "low", "mid", "high")["x"]).to eq("high")
      expect(%w[x].map(&p.choose("q?", a: "1", b: "2"))).to all(be_a(S1::Answer::Choice))
      expect(%w[x].map(&p.choice("q?", a: "1", b: "2"))).to eq([:b])
      expect(%w[x].map(&p.score("q?", "low", "mid", "high"))).to all(be_a(S1::Answer::Score))
      expect(%w[x].map(&p.judge("q?"))).to all(be_a(S1::Answer::Noul))
    end
  end

  describe "#to_s1" do
    it "is itself with no options, and the same rendering under them otherwise" do
      S1.config.provider = S1::Providers::Stub.new(noul: 0.9)
      state = described_class.new("x", owner: :me, provider: S1::Providers::Stub.new(noul: 0.7))
      expect(state.to_s1).to be(state)
      strict = state.to_s1(threshold: 0.99)
      expect(strict).not_to be(state)
      expect(strict.rendered).to eq("x")
      expect(strict.threshold).to eq(0.99)
      expect(strict.judge?("q?")).to be(false)
      expect(strict.judge("q?").to_f).to eq(0.7)
      expect(strict.options).to eq(owner: :me)
      expect(state.to_s1(trace: 1).options).to eq(owner: :me, trace: 1)
      expect(S1.to_state(state, threshold: 0.99).threshold).to eq(0.99)
      expect(S1.to_state(state).threshold).to eq(0.5)
      expect(state.threshold).to eq(0.5)
      expect(S1.predicates.judge?("q?").measure(state.to_s1(threshold: 0.99)).threshold).to eq(0.99)
    end

    it "keeps the evidence under a lens" do
      S1.config.provider = S1::Providers::Stub.new(choice: :bob)
      lensed = described_class.new(%w[ann bob]).given(role: "pilot").to_s1(threshold: 0.9)
      expect(lensed.choose("Who flies?").categories).to eq(%i[ann bob])
      expect(lensed.threshold).to eq(0.9)
    end
  end

  describe "#choose" do
    it "takes categories: as the scale, including a bare list of labels" do
      S1.config.provider = S1::Providers::Stub.new(choice: :b, pick: :a)
      expect(described_class.new("x").choose("q?", categories: { a: "1", b: "2" }).to_sym).to eq(:b)
      expect(described_class.new("x").choose("q?", categories: %w[a b]).probabilities.keys).to eq(%w[a b])
      expect(described_class.new("x").measure { |q| q.choose :pick, "q?", categories: %w[a b] }[:pick].to_sym).to eq(:a)
      expect(described_class.new("x").choose("q?", categories: %w[a b], given: { p: 1 }).categories).to eq(%i[a b])
    end

    it "still takes choices: and criteria: for the same thing" do
      S1.config.provider = S1::Providers::Stub.new(choice: :b, pick: :a)
      expect(described_class.new("x").choose("q?", choices: { a: "1", b: "2" }).to_sym).to eq(:b)
      expect(described_class.new("x").choose("q?", criteria: { a: "1", b: "2" }).to_sym).to eq(:b)
      expect(described_class.new("x").choose("q?", choices: %w[a b]).probabilities.keys).to eq(%w[a b])
      expect(described_class.new("x").ask { |q| q.choose :pick, "q?", choices: %w[a b] }[:pick].to_sym).to eq(:a)
      expect { described_class.new("x").choose("q?", choices: [{ name: "a" }, { name: "b" }]) }.to raise_error(S1::ValidationError)
    end

    it "chooses among the evidence: a categories-shaped state is its own scale when none is given" do
      S1.config.provider = S1::Providers::Stub.new(choice: :bob)
      expect(described_class.new({ "ann" => "a farmer", "bob" => "a pilot" }).choose("Who flies?").probabilities.keys).to eq(%w[ann bob])
      expect(described_class.new(%w[ann bob]).choose("Who flies?").to_sym).to eq(:bob)
      expect do
        described_class.new({ transcript: "hi", case: { a: 1 } }).choose("Which?")
      end.to raise_error(S1::ValidationError, /pass categories:/)
      expect { described_class.new("just text").choose("Which?") }.to raise_error(S1::ValidationError, /pass categories:/)
    end

    it "reads a Symbol-keyed Hash as a record, never as candidates: choose takes categories: there" do
      asked = []
      S1.config.provider = S1::Providers::Stub.new do |req|
        asked << req.questions[:choice].categories and { choice: req.questions[:choice].categories.last }
      end
      record = described_class.new({ ticket: "Refund my order", customer: "Ann Lee" })
      expect { record.choose("Which team?") }
        .to raise_error(S1::ValidationError, "choose needs a scale: pass categories: (the facts are not candidates-shaped)")
      expect(record.choose("Which team?", categories: %w[returns billing]).to_sym).to eq(:billing)
      expect(record.choose("Which team?", returns: "Refunds", billing: "Charges").to_sym).to eq(:billing)
      expect(asked).to eq([%w[returns billing], %w[returns billing]])
      mixed = described_class.new({ "a" => nil, "b" => "described" })
      expect { mixed.choose("Which?") }.to raise_error(S1::ValidationError, /pass categories:/)
      expect { described_class.new({ "a" => 1, "b" => 2 }).choose("Which?") }.to raise_error(S1::ValidationError, /pass categories:/)
      expect { described_class.new(%i[a b]).choose("Which?") }.to raise_error(S1::ValidationError, /pass categories:/)
      expect(described_class.new({ "a" => nil, "b" => nil }).choose("Which?").categories).to eq(%i[a b])
      parsed = described_class.new(JSON.parse('{"ticket":"Refund my order","customer":"Ann Lee"}'))
      expect(parsed.choose("Which team?").categories).to eq(%i[ticket customer])
      expect(parsed.choose("Which team?", categories: %w[returns billing]).categories).to eq(%i[returns billing])
    end

    it "chooses among the evidence under a lens, inline or fluent: the candidates stay the scale" do
      seen = []
      S1.config.provider = S1::Providers::Stub.new do |req|
        seen << req and { choice: req.questions[:choice].categories.find { |c| c == "Bob" } || req.questions[:choice].categories.first }
      end
      people = described_class.new(%w[Michael Bob Dana])
      expect(people.choose("the most skilled at `role`", given: { role: "chef" }).categories).to eq(%i[Michael Bob Dana])
      expect(people.given(role: "chef").choose("the most skilled at `role`").categories).to eq(%i[Michael Bob Dana])
      expect(people.choice("the most skilled at `role`", given: { role: "chef" })).to be(:Bob)
      expect(people.against(role: "chef").choice("the most skilled at `role`")).to be(:Bob)
      expect(seen.map(&:state).uniq).to eq([{ this: %w[Michael Bob Dana], role: "chef" }])
      expect(seen.map { |r| r.questions[:choice].categories }.uniq).to eq([%w[Michael Bob Dana]])
      seen.clear
      described = described_class.new({ "ann" => "a farmer", "bob" => "a pilot" })
      expect(described.given(role: "pilot").choose("Who fits `role`?").categories).to eq(%i[ann bob])
      expect(people.given(role: "chef").evidence).to eq(%w[Michael Bob Dana])
      expect(people.evidence).to be(people.rendered)
      expect(people.given(a: 1).given(b: 2).evidence).to eq(%w[Michael Bob Dana])
      expect(people.given(role: "chef").choose("Which?", a: "A", b: "B").categories).to eq(%i[a b])
    end

    it "is the verb in the batch builder too, where noul aliases judge and choice does not exist" do
      S1.config.provider = S1::Providers::Stub.new(choice: :b, pick: :a)
      expect(described_class.new("x").choose("q?", a: "1", b: "2").to_sym).to eq(:b)
      expect(described_class.new("x").measure { |q| q.choose :pick, "q?", a: "1", b: "2" }[:pick].to_sym).to eq(:a)
      expect { described_class.new("x").measure { |q| q.choice :pick, "q?", a: "1", b: "2" } }.to raise_error(NoMethodError, /choice/)
      expect(described_class.new("x").measure { |q| q.judge :e, "q?" }[:e]).to be_a(S1::Answer::Noul)
      expect(described_class.new("x").measure { |q| q.noul :e, "q?" }[:e]).to be_a(S1::Answer::Noul)
    end

    it "returns an Answer::Choice" do
      S1.config.provider = S1::Providers::Stub.new(choice: :billing)
      answer = described_class.new("text").choose("Which?", returns: "R", billing: "B")
      expect(answer).to be_a(S1::Answer::Choice)
      expect(answer.id).to eq(:choice)
      expect(answer.to_sym).to eq(:billing)
      expect(answer.probabilities.keys).to eq(%w[returns billing])
    end
  end

  describe "#score" do
    it "returns an Answer::Score" do
      S1.config.provider = S1::Providers::Stub.new(score: 2)
      answer = described_class.new("text").score("How?", "low", "mid", "high")
      expect(answer).to be_a(S1::Answer::Score)
      expect(answer.id).to eq(:score)
      expect(answer.level).to eq("high")
      expect(answer.levels).to eq(%w[low mid high])
    end
  end

  describe "#measure" do
    let(:state) { described_class.new("text") }

    it "accepts a block" do
      result = state.measure do |q|
        q.judge :a, "A?"
        q.choose :b, "B?", x: "X", y: "Y"
      end
      expect(result).to be_a(S1::Result)
      expect(result.distributions.keys).to eq(%i[a b])
    end

    it "accepts a Questions" do
      questions = S1::Questions.new
      questions.judge(:a, "A?")
      expect(state.measure(questions).distributions.keys).to eq([:a])
    end

    it "accepts a Hash of Question" do
      result = state.measure("a" => S1::Question::Noul.new(instructions: "A?"))
      expect(result[:a]).to be_a(S1::Answer::Noul)
    end

    it "measures a Questions and a block together" do
      questions = S1::Questions.new
      questions.judge(:a, "A?")
      result = state.measure(questions) { |q| q.choose :b, "B?", x: "X", y: "Y" }
      expect(result.distributions.keys).to eq(%i[a b])
      expect(result[:b]).to be_a(S1::Answer::Choice)
      expect(state.measure({ "a" => S1::Question::Noul.new(instructions: "A?") }) { |q| q.judge :b, "B?" }.distributions.keys)
        .to eq(%i[a b])
    end

    it "raises without questions" do
      expect { state.measure }.to raise_error(S1::ValidationError, /no questions/)
    end

    it "rides extra options along on the Request" do
      captured = nil
      S1.on_result { |_result, request| captured = request }
      described_class.new("text", owner: "firm-1", trace: 7).measure { |q| q.judge(:a, "A?") }
      expect(captured.options).to eq(owner: "firm-1", trace: 7)
    end
  end

  describe "per-State overrides" do
    it "uses provider: over the config" do
      other = S1::Providers::Stub.new(noul: 0.1)
      expect(described_class.new("text", provider: other).judge("Is it?").to_f).to eq(0.1)
      expect(described_class.new("text", provider: :stub).judge("Is it?").to_f).to eq(0.5)
    end

    it "uses model: and timeout: over the config" do
      captured = nil
      S1.on_result { |_result, request| captured = request }

      described_class.new("text").judge("Is it?")
      expect(captured.model).to be_nil
      expect(captured.timeout).to eq(30)

      described_class.new("text", model: "jev-2026", timeout: 3).judge("Is it?")
      expect(captured.model).to eq("jev-2026")
      expect(captured.timeout).to eq(3)
    end
  end
end
