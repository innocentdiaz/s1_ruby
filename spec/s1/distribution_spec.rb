# frozen_string_literal: true

RSpec.describe S1::Distribution do
  it "is what Answer::Base named, and is abstract about its scale" do
    expect(S1::Answer::Base).to be(described_class)
    expect(described_class.ancestors).to include(S1::Collapsable)
    bare = described_class.new(id: :x, probabilities: { "a" => 1.0 }, confidence: nil)
    expect { bare.scale }.to raise_error(NotImplementedError, /scale/)
    expect { bare.collapse }.to raise_error(NotImplementedError, /collapse/)
  end

  it "names its kind by the theory's word and its type by the wire's, the same string" do
    noul = S1::Answer::Noul.new(id: :a, probability: 0.5)
    choice = S1::Answer::Choice.new(id: :b, choice: "x", probabilities: { "x" => 1.0 }, confidence: 1.0)
    score = S1::Answer::Score.new(id: :c, legend: { 0 => "lo", 1 => "hi" }, probabilities: { "0" => 1.0 }, confidence: 1.0)
    expect([noul, choice, score].map(&:kind)).to eq(%w[noul choice score])
    expect([noul, choice, score].map(&:type)).to eq(%w[noul choice score])
    expect([noul, choice, score]).to all(be_a(described_class))
  end

  it "gives each kind its scale: booleans, categories as Symbols, levels" do
    noul = S1::Answer::Noul.new(id: :a, probability: 0.5)
    choice = S1::Answer::Choice.new(id: :b, choice: "y", probabilities: { "x" => 0.4, "y" => 0.6 }, confidence: 0.6)
    score = S1::Answer::Score.new(id: :c, legend: { 0 => "lo", 1 => "hi" },
                                  probabilities: { "0" => 0.5, "1" => 0.5 }, confidence: 0.5)
    expect(noul.scale).to eq([true, false])
    expect(choice.scale).to eq(S1.scale("x", "y", ordered: false))
    expect(choice.scale.to_a).to eq(%i[x y])
    expect(score.scale).to eq(S1.scale("lo", "hi"))
    expect(score.scale.to_a).to all(be_a(S1::Level))
    expect(score.scale.to_a).to eq(score.levels)
    [noul, choice, score].each { |d| expect(d.scale).to include(d.collapse) }
  end

  describe S1::Answer::Noul do
    let(:answer) { described_class.new(id: "escalate", probability: 0.94) }

    it "is frozen and symbolizes its id" do
      expect(answer).to be_frozen
      expect(answer.id).to eq(:escalate)
      expect(answer.type).to eq("noul")
      expect(answer.kind).to eq("noul")
      expect(answer.confidence).to be_nil
    end

    it "reads as a float" do
      expect(answer.to_f).to eq(0.94)
      expect(answer.probability).to eq(0.94)
      expect(described_class.new(id: :x, probability: "0.25").to_f).to eq(0.25)
    end

    it "thresholds at the configured default" do
      expect(answer.true?).to be(true)
      expect(answer.false?).to be(false)
      low = described_class.new(id: :x, probability: 0.3)
      expect(low.true?).to be(false)
      expect(low.false?).to be(true)
      expect(described_class.new(id: :x, probability: 0.5).true?).to be(true)
    end

    it "thresholds with an explicit value" do
      expect(answer.true?(0.95)).to be(false)
      expect(answer.false?(0.95)).to be(true)
      expect(answer.true?(0.9)).to be(true)
    end

    it "carries the config's threshold as of its construction; a later change does not reach it" do
      expect(answer.threshold).to eq(0.5)
      expect(answer.true?).to be(true)
      S1.config.threshold = 0.95
      expect(answer.threshold).to eq(0.5)
      expect(answer.true?).to be(true)
      expect(answer.collapse).to be(true)
      expect(described_class.new(id: :x, probability: 0.94).threshold).to eq(0.95)
      expect(described_class.new(id: :x, probability: 0.94).true?).to be(false)
      expect((answer & described_class.new(id: :y, probability: 1.0)).threshold).to eq(0.5)
      expect(S1::Result.new(distributions: { a: answer }, threshold: nil)[:a].threshold).to eq(0.5)
      expect(S1::Result.new(distributions: { a: answer }).threshold).to eq(0.5)
      expect(S1::Result.new(distributions: { a: answer }).with_threshold(nil)[:a].threshold).to eq(0.95)
    end

    it "carries the threshold it was measured under, and copies with another" do
      strict = described_class.new(id: :x, probability: 0.94, threshold: 0.95, raw: { "noul" => 0.94 })
      expect(strict.threshold).to eq(0.95)
      expect(strict.true?).to be(false)
      expect(strict.false?).to be(true)
      expect(strict.collapse).to be(false)
      expect(!strict).to be(true)
      expect(strict.true?(0.9)).to be(true)
      expect(strict.undecided?(0.05)).to be(true)
      expect(strict.confident?).to be(false)
      loose = strict.with(threshold: 0.5)
      expect(loose.threshold).to eq(0.5)
      expect(loose.true?).to be(true)
      expect([loose.id, loose.probability, loose.raw]).to eq([:x, 0.94, { "noul" => 0.94 }])
      expect(strict.with(threshold: nil).threshold).to eq(0.5)
      S1.config.threshold = 0.9
      expect(strict.with(threshold: nil).threshold).to eq(0.9)
    end

    it "compares against numbers in both directions" do
      expect(answer >= 0.85).to be(true)
      expect(answer > 0.94).to be(false)
      expect(answer).to eq(0.94)
      expect(0.85 <= answer).to be(true) # rubocop:disable Style/YodaCondition
      expect(0.99 > answer).to be(true) # rubocop:disable Style/YodaCondition
      expect(1 < answer).to be(false) # rubocop:disable Style/YodaCondition
    end

    it "is incomparable with, and so never equal to, anything but a number or a noul" do
      expect(answer <=> :x).to be_nil
      expect(answer == :x).to be(false)
      expect(answer == true).to be(false)
      expect(answer == nil).to be(false) # rubocop:disable Style/NilComparison
      expect(answer == "0.94").to be(false)
      expect { answer > :x }.to raise_error(ArgumentError)
      expect(answer <=> described_class.new(id: :y, probability: 0.94)).to eq(0)
      expect(answer == described_class.new(id: :y, probability: 0.94)).to be(true)
      expect(answer <=> 1).to eq(-1)
    end

    it "sorts by probability" do
      a = described_class.new(id: :a, probability: 0.7)
      b = described_class.new(id: :b, probability: 0.2)
      c = described_class.new(id: :c, probability: 0.9)
      expect([a, b, c].sort.map(&:id)).to eq(%i[b a c])
      expect([a, b, c].max.id).to eq(:c)
      expect(a.between?(0.5, 0.8)).to be(true)
    end

    it "exposes a true/false distribution" do
      expect(answer.probabilities.keys).to eq(%w[true false])
      expect(answer.probabilities["true"]).to eq(0.94)
      expect(answer.probabilities["false"]).to be_within(1e-9).of(0.06)
      expect(answer.probabilities).to be_frozen
    end

    it "is a Collapsable, like every distribution and a Result" do
      expect(described_class.new(id: :x, probability: 0.9)).to be_a(S1::Collapsable)
      expect(S1::Answer::Choice.new(id: :x, choice: "a", probabilities: { "a" => 1.0 }, confidence: 1.0)).to be_a(S1::Collapsable)
      expect(S1::Result.new(distributions: {})).to be_a(S1::Collapsable)
      expect(S1::Result.new(distributions: {}).collapse).to eq({})
    end

    describe "probability algebra and the named collapse" do
      let(:a) { described_class.new(id: :a, probability: 0.9) }
      let(:b) { described_class.new(id: :b, probability: 0.5) }

      it "combines independent nouls as both / either / not" do
        expect((a & b).to_f).to be_within(1e-9).of(0.45)
        expect((a | b).to_f).to be_within(1e-9).of(0.95)
        expect((~a).to_f).to be_within(1e-9).of(0.1)
        expect((a & b).id).to eq(:"a&b")
        expect(a & b).to be_a(described_class)
        expect((a & b) >= 0.4).to be(true)
      end

      it "takes a number as the other operand: a marginal already known" do
        expect((a & 0.5).to_f).to be_within(1e-9).of(0.45)
        expect((a | 0.5).to_f).to be_within(1e-9).of(0.95)
        expect((a & 0.5).id).to eq(:"a&0.5")
        expect((a | 1).id).to eq(:"a|1")
        expect(a & 0.5).to be_a(described_class)
        strict = described_class.new(id: :s, probability: 0.9, threshold: 0.95)
        expect((strict & 1.0).threshold).to eq(0.95)
        expect((strict & 1.0).collapse).to be(false)
      end

      it "refuses any other operand — nil, a boolean, a String, a number off 0..1 — as an ArgumentError" do
        expect { a & nil }.to raise_error(ArgumentError, ":a: the other operand must be a noul or a number in 0..1 (got nil)")
        expect { a | true }.to raise_error(ArgumentError, ":a: the other operand must be a noul or a number in 0..1 (got true)")
        expect { a & "0.5" }.to raise_error(ArgumentError, /got "0.5"/)
        expect { a | 1.5 }.to raise_error(ArgumentError, /got 1.5/)
        expect { a & -0.1 }.to raise_error(ArgumentError, /got -0.1/)
      end

      it "carries the left operand's threshold through & | ~" do
        strict = described_class.new(id: :s, probability: 0.9, threshold: 0.95)
        expect((strict & a).threshold).to eq(0.95)
        expect((a & strict).threshold).to eq(0.5)
        expect((strict | a).threshold).to eq(0.95)
        expect((~strict).threshold).to eq(0.95)
        expect((~strict).true?).to be(false)
        expect((strict | a).true?).to be(true)
        expect(!!(strict & a)).to be(false) # rubocop:disable Style/DoubleNegation
      end

      it "collapses through !! (and negates through !), but stays truthy to a bare if" do
        expect(!!a).to be(true) # rubocop:disable Style/DoubleNegation
        expect(!a).to be(false)
        expect(!!described_class.new(id: :x, probability: 0.2)).to be(false) # rubocop:disable Style/DoubleNegation
        expect(a ? :truthy : :falsy).to eq(:truthy) # the trap: no `!` involved
      end

      it "collapses to a boolean at a threshold, and knows when it is too close to call" do
        expect(a.collapse).to be(true)
        expect(b.collapse(0.6)).to be(false)
        expect(b.undecided?).to be(true)
        expect(a.undecided?).to be(false)
        expect(b.undecided?(0.01, threshold: 0.6)).to be(false)
      end

      it "routes with plain case/when on ranges" do
        route = case a
                when 0.85.. then :auto
                when 0.5...0.85 then :review
                else :reject
                end
        expect(route).to eq(:auto)
      end
    end

    describe "#confident?" do
      it "is distance from the threshold, on either side: the complement of undecided?" do
        expect(described_class.new(id: :x, probability: 0.16, threshold: 0.85)).to be_confident
        expect(described_class.new(id: :x, probability: 0.3, threshold: 0.8)).to be_confident
        expect(described_class.new(id: :x, probability: 0.84, threshold: 0.85)).not_to be_confident
        expect(described_class.new(id: :x, probability: 0.5)).not_to be_confident
        expect(described_class.new(id: :x, probability: 0.61)).to be_confident
        [0.5, 0.61, 0.84, 0.16].each do |p|
          noul = described_class.new(id: :x, probability: p, threshold: 0.85)
          expect(noul.confident?).to eq(!noul.undecided?), p.to_s
        end
      end

      it "takes a margin, and a threshold: to measure the distance from" do
        expect(described_class.new(id: :x, probability: 0.95).confident?(0.4)).to be(true)
        expect(described_class.new(id: :x, probability: 0.05).confident?(0.4)).to be(true)
        expect(described_class.new(id: :x, probability: 0.55).confident?(0.4)).to be(false)
        expect(described_class.new(id: :x, probability: 0.7).confident?(0.1, threshold: 0.75)).to be(false)
        expect(described_class.new(id: :x, probability: 0.7).confident?(0.1, threshold: 0.5)).to be(true)
        expect(described_class.new(id: :x, probability: 0.85).confident?(0.8)).to be(false)
        expect(described_class.new(id: :x, probability: 0.85).confident?(0.3)).to be(true)
        expect(described_class.new(id: :x, probability: 0.85).confident?(0.3, threshold: 0.8)).to be(false)
      end

      it "uses its own threshold by default: the configured one, or the one it was measured under" do
        S1.config.threshold = 0.8
        expect(described_class.new(id: :x, probability: 0.75)).not_to be_confident
        expect(described_class.new(id: :x, probability: 0.6)).to be_confident
        expect(described_class.new(id: :x, probability: 0.85, threshold: 0.9)).not_to be_confident
      end

      it "is a margin on a noul and a floor on a choice: the positional inverts between the two, and decided? names the noul's" do
        noul = described_class.new(id: :x, probability: 0.85)
        expect(noul.confident?(0.8)).to be(false)
        expect(noul.confident?(0.3)).to be(true)
        choice = S1::Answer::Choice.new(id: :c, choice: "a", probabilities: { "a" => 0.85, "b" => 0.15 }, confidence: 0.85)
        expect(choice.confident?(0.8)).to be(true)
        expect(choice.confident?(0.9)).to be(false)
        expect(noul.decided?(0.8)).to be(false)
        expect(noul.decided?(0.3)).to be(true)
        expect(noul.decided?).to eq(noul.confident?)
        expect(noul.method(:decided?)).to eq(noul.method(:confident?))
        expect(noul.decided?(0.1, threshold: 0.9)).to eq(noul.confident?(0.1, threshold: 0.9))
      end
    end
  end

  describe S1::Answer::Choice do
    let(:answer) do
      described_class.new(id: :department, choice: :billing,
                          probabilities: { returns: 0.1, "billing" => 0.85, shipping: 0.05 }, confidence: 0.85)
    end

    it "is frozen" do
      expect(answer).to be_frozen
      expect(answer.type).to eq("choice")
      expect(answer.confidence).to eq(0.85)
    end

    it "reads as a string or a symbol; the choice itself is the Symbol" do
      expect(answer.to_s).to eq("billing")
      expect(answer.to_sym).to eq(:billing)
      expect(answer.choice).to be(:billing)
      expect(answer.collapse).to be(:billing)
      expect(answer.collapse(0.9)).to be(:billing)
    end

    it "indexes probabilities by string or symbol" do
      expect(answer[:returns]).to eq(0.1)
      expect(answer["billing"]).to eq(0.85)
      expect(answer[:missing]).to be_nil
      expect(answer.probabilities.keys).to eq(%w[returns billing shipping])
    end

    it "lists its categories as Symbols in wire order, the points of its nominal scale; options is the old name" do
      expect(answer.categories).to eq(%i[returns billing shipping])
      expect(answer.options).to eq(answer.categories)
      expect(answer.scale).to be_a(S1::Scale).and be_nominal
      expect(answer.scale.to_a).to eq(answer.categories)
      expect(answer.scale).to include(answer.choice)
    end

    it "keeps the question's scale, definitions and all; a wire category or choice off it raises, and none builds one from the wire" do
      team = S1.scale(returns: "Refunds", billing: "Charges")
      kept = described_class.new(id: :x, choice: :billing, probabilities: { billing: 0.9, returns: 0.1 }, confidence: 0.9, scale: team)
      expect(kept.scale).to be(team)
      expect(kept.scale.definitions["billing"]).to eq("Charges")
      expect { described_class.new(id: :x, choice: :billing, probabilities: { billing: 0.9, legal: 0.1 }, confidence: 0.9, scale: team) }
        .to raise_error(S1::ValidationError, ':x: ["legal"] are not on #<S1::Scale returns | billing>')
      expect { described_class.new(id: :x, choice: "zzz", probabilities: {}, confidence: nil, scale: team) }
        .to raise_error(S1::ValidationError, ':x: ["zzz"] are not on #<S1::Scale returns | billing>')
      expect(described_class.new(id: :x, choice: "a", probabilities: {}, confidence: nil).scale.size).to eq(0)
      expect(described_class.new(id: :x, choice: :billing, probabilities: { billing: 0.9, legal: 0.1 }, confidence: 0.9).scale)
        .to eq(S1.scale("billing", "legal", ordered: false))
    end

    it "keeps the question's scale when the wire left a zero-mass category out, giving it mass 0; a dynamic scale is none" do
      team = S1.scale(returns: "Refunds", billing: "Charges")
      sparse = described_class.new(id: :x, choice: :billing, probabilities: { billing: 1.0 }, confidence: 1.0, scale: team)
      expect(sparse.scale).to be(team)
      expect(sparse.probabilities).to eq("returns" => 0.0, "billing" => 1.0)
      expect(sparse.categories).to eq(%i[returns billing])
      expect(sparse[:returns]).to eq(0.0)
      expect(sparse.ranked).to eq(%i[billing returns])
      dynamic = described_class.new(id: :x, choice: :billing, probabilities: { billing: 1.0 }, confidence: 1.0, scale: S1.scale(:teams))
      expect(dynamic.scale).to eq(S1.scale("billing", ordered: false))
    end

    it "equals a string or a symbol" do
      expect(answer == :billing).to be(true)
      expect(answer == "billing").to be(true)
      expect(answer == :returns).to be(false)
      expect(answer).to eq(described_class.new(id: :x, choice: "billing", probabilities: {}, confidence: nil))
    end

    it "routes on confidence at a given level, never a borrowed one" do
      expect(answer.confident?(0.8)).to be(true)
      expect(answer.confident?(0.9)).to be(false)
      expect { answer.confident? }.to raise_error(ArgumentError)
    end

    it "ranks every category as a Symbol, most likely first, so the ranking's head is the choice" do
      answer = described_class.new(id: :x, choice: "b", probabilities: { "a" => 0.2, "b" => 0.7, "c" => 0.1 }, confidence: 0.7)
      expect(answer.ranked).to eq(%i[b a c])
      expect(answer.ranked.first).to eq(answer.choice)
      expect(answer.scale).to include(answer.ranked.first)
    end

    it "collapses to the most likely category by mass; the provider's pick only breaks a tie" do
      disagree = described_class.new(id: :x, choice: :billing, probabilities: { returns: 0.9, billing: 0.1 }, confidence: 1.0)
      expect(disagree.collapse).to be(:returns)
      expect(disagree.choice).to be(:returns)
      expect(disagree.to_sym).to be(:returns)
      expect(disagree.ranked.first).to eq(disagree.collapse)
      tied = described_class.new(id: :x, choice: :billing, probabilities: { returns: 0.5, billing: 0.5 }, confidence: 1.0)
      expect(tied.collapse).to be(:billing)
      expect(described_class.new(id: :x, choice: "a", probabilities: {}, confidence: nil).collapse).to be(:a)
    end

    it "is eql? by category, so equal choices bucket together" do
      a1 = described_class.new(id: :x, choice: "a", probabilities: { "a" => 0.9, "b" => 0.1 }, confidence: 0.9)
      a2 = described_class.new(id: :y, choice: "a", probabilities: { "a" => 0.6, "b" => 0.4 }, confidence: 0.6)
      b = described_class.new(id: :z, choice: "b", probabilities: { "a" => 0.1, "b" => 0.9 }, confidence: 0.9)
      expect(a1).to eql(a2)
      expect(a1.hash).to eq(a2.hash)
      expect(a1).not_to eql(b)
      expect([a1, a2, b].uniq.size).to eq(2)
      expect([a1, a2, b].group_by(&:itself).keys).to eq(%i[a b])
    end

    it "is confident when the provider reported no confidence: the gate opens on nil, and confidence itself is nil to read" do
      unknown = described_class.new(id: :x, choice: "a", probabilities: {}, confidence: nil)
      expect(unknown).to be_confident(1.0)
      expect(unknown).to be_confident(0.99)
      expect(unknown.confidence).to be_nil
    end
  end

  describe S1::Answer::Score do
    let(:answer) do
      described_class.new(id: :severity,
                          legend: { "0" => "Cosmetic", "1" => "Degraded", "2" => "Blocking" },
                          probabilities: { "0" => 0.05, "1" => 0.22, "2" => 0.73 }, confidence: 0.73)
    end

    it "is frozen, and keeps the legend to itself" do
      expect(answer).to be_frozen
      expect(answer.type).to eq("score")
      expect(answer).not_to respond_to(:legend)
    end

    it "reads as the expectation, the probability-weighted position; score is the old name" do
      expect(answer.to_f).to be_within(1e-9).of(1.68)
      expect(answer.expectation).to be_within(1e-9).of(1.68)
      expect(answer.score).to eq(answer.expectation)
    end

    it "always derives the expectation from the ordinal distribution: a provider's own number is accepted and ignored" do
      derived = described_class.new(id: :x, legend: { 0 => "lo", 1 => "hi" }, probabilities: { "0" => 0.2, "1" => 0.8 }, confidence: 1)
      expect(derived.expectation).to be_within(1e-9).of(0.8)
      expect(derived.to_f).to eq(derived.expectation)
      expect(derived.level).to eq("hi")
      expect(described_class.new(id: :x, legend: { 1 => "lo", 2 => "hi" }, probabilities: { "1" => 0.5, "2" => 0.5 },
                                 confidence: 1).expectation).to eq(0.5)
      expect { described_class.new(id: :x, legend: { 0 => "a", 1 => "b" }, probabilities: {}, confidence: 1) }
        .to raise_error(S1::ValidationError, ":x: a score needs mass on at least one legend key")
      expect { described_class.new(id: :x, legend: { 5 => "a", 6 => "b" }, probabilities: nil, confidence: nil) }
        .to raise_error(S1::ValidationError, /:x: a score needs mass/)
      legend = { 0 => "a", 1 => "b" }
      given = described_class.new(id: :s, legend: legend, probabilities: { "0" => 0.3, "1" => 0.7 }, confidence: 0.7, expectation: 0.1)
      expect(given.expectation).to be_within(1e-9).of(0.7)
      expect(given.raw).to be_nil
      wire = described_class.new(id: :x, score: 0, legend: legend, probabilities: { "1" => 1.0 }, confidence: 1, raw: { "score" => 0 })
      expect(wire.expectation).to eq(1.0)
      expect(wire.raw).to eq("score" => 0)
      both = described_class.new(id: :x, expectation: 0, score: 0, legend: legend, probabilities: { "1" => 1.0 }, confidence: 1)
      expect(both.to_f).to eq(1.0)
    end

    it "re-keys the legend and the mass by rank on a legend that does not start at 0: key is the position, the wire's key is raw's" do
      wire = { "5" => 0.1, "6" => 0.8, "7" => 0.1 }
      shifted = described_class.new(id: :s, legend: { 5 => "low", 6 => "mid", 7 => "high" }, probabilities: wire, confidence: 0.8,
                                    raw: wire)
      expect(shifted.probabilities).to eq("0" => 0.1, "1" => 0.8, "2" => 0.1)
      expect(shifted.key).to eq(1)
      expect(shifted.index).to eq(1)
      expect(shifted.key).to eq(shifted.level.position)
      expect(shifted.level).to eq("mid")
      expect(shifted.levels.map(&:position)).to eq([0, 1, 2])
      expect(shifted.expectation).to be_within(1e-9).of(1.0)
      expect(shifted.to_s).to eq('1 "mid"')
      expect(shifted.raw).to eq(wire)
      by_rank = described_class.new(id: :s, legend: { 0 => "low", 1 => "mid", 2 => "high" },
                                    probabilities: { "0" => 0.1, "1" => 0.8, "2" => 0.1 }, confidence: 0.8)
      expect(shifted.probabilities).to eq(by_rank.probabilities)
      expect(shifted.to_s).to eq(by_rank.to_s)
    end

    it "positions a level by rank on the scale, whatever the legend's keys" do
      shifted = described_class.new(id: :s, legend: { 1 => "lo", 2 => "hi" }, probabilities: { "1" => 1.0, "2" => 0.0 }, confidence: 1)
      expect(shifted.level).to eq("lo")
      expect(shifted.level.position).to eq(0)
      expect(shifted.level).to eq(shifted.scale.first)
      expect(shifted.level.position).to eq(shifted.scale.first.position)
      expect(shifted.level >= "hi").to be(false)
      expect(shifted.level < "hi").to be(true)
      expect(shifted.key).to eq(0)
      expect(shifted.to_s).to eq('0 "lo"')
      expect(shifted.expectation).to eq(0.0)
    end

    it "picks the most likely level" do
      expect(answer.key).to eq(2)
      expect(answer.level).to eq("Blocking")
    end

    it "collapses to a Level: the label, knowing its position" do
      level = answer.collapse
      expect(level).to be_a(S1::Level)
      expect(level).to eq("Blocking")
      expect(level.position).to eq(2)
      expect(level.scale).to eq(S1.scale("Cosmetic", "Degraded", "Blocking"))
      expect(level.scale).to be(answer.scale)
      expect(answer.collapse(0.9)).to eq(level)
      expect(answer.level).to be_a(S1::Level)
    end

    it "lists every level as a Level" do
      expect(answer.levels).to all(be_a(S1::Level))
      expect(answer.levels).to eq(%w[Cosmetic Degraded Blocking])
      expect(answer.levels.map(&:position)).to eq([0, 1, 2])
      expect(answer.levels.max).to eq("Blocking")
    end

    it "carries its question's ordinal scale when the legend is its labels or its texts; another legend raises, none builds one" do
      severity = S1.scale("Cosmetic", "Degraded", "Blocking", name: "Severity")
      kept = described_class.new(id: :s, legend: { 0 => "Cosmetic", 1 => "Degraded", 2 => "Blocking" },
                                 probabilities: { "1" => 1.0 }, confidence: 1, scale: severity)
      expect(kept.scale).to be(severity)
      expect(kept.level.scale).to be(severity)
      expect(kept.levels.map(&:scale)).to all(be(severity))
      expect(kept.level.degraded?).to be(true)
      expect(answer.scale).to be_a(S1::Scale).and be_ordinal
      expect(answer.scale).to eq(severity)
      expect(answer.scale.name).to be_nil
      expect do
        described_class.new(id: :s, legend: { 0 => "lo", 1 => "hi" }, probabilities: { "1" => 1.0 }, confidence: 1, scale: severity)
      end
        .to raise_error(S1::ValidationError, ':s: the legend ["lo", "hi"] is not #<S1::Scale Severity Cosmetic < Degraded < Blocking>')
      three = { 0 => "Cosmetic", 1 => "Degraded", 2 => "Blocking", 3 => "Fatal" }
      expect { described_class.new(id: :s, legend: three, probabilities: { "1" => 1.0 }, confidence: 1, scale: severity) }
        .to raise_error(S1::ValidationError, /the legend \["Cosmetic", "Degraded", "Blocking", "Fatal"\] is not/)
      other = described_class.new(id: :s, legend: { 0 => "lo", 1 => "hi" }, probabilities: { "1" => 1.0 }, confidence: 1)
      expect(other.scale).to eq(S1.scale("lo", "hi"))
    end

    it "coerces legend keys to Integer" do
      expect(answer.levels.map(&:position)).to eq([0, 1, 2])
      sym = described_class.new(id: :x, legend: { 1 => "b", :"0" => "a" }, probabilities: { 0 => 0.9, 1 => 0.1 }, confidence: 1)
      expect(sym.levels).to eq(%w[a b])
      expect(sym.key).to eq(0)
      expect(sym.level).to eq("a")
    end

    it "rejects a probability for a key the legend does not have" do
      expect do
        described_class.new(id: :severity, legend: { "0" => "a", "1" => "b" }, probabilities: { "0" => 0.2, "3" => 0.8 }, confidence: 0.8)
      end.to raise_error(S1::ValidationError, /:severity.*key "3".*legend \[0, 1\]/)
      expect do
        described_class.new(id: :x, legend: { 0 => "a", 1 => "b" }, probabilities: { "a" => 1.0 }, confidence: 1)
      end.to raise_error(S1::ValidationError, /:x.*key "a"/)
    end

    it "orders levels regardless of legend order" do
      out_of_order = described_class.new(id: :x, legend: { "2" => "c", "0" => "a", "1" => "b" },
                                         probabilities: { "1" => 1.0 }, confidence: 1)
      expect(out_of_order.levels).to eq(%w[a b c])
      expect(out_of_order.key).to eq(1)
      expect(out_of_order.level).to eq("b")
    end

    it "routes on confidence at a given level, never a borrowed one" do
      expect(answer.confident?(0.7)).to be(true)
      expect(answer.confident?(0.75)).to be(false)
      expect { answer.confident? }.to raise_error(ArgumentError)
    end

    it "compares by expectation against a number or another score, so a stream sorts and sums by it" do
      legend = { 0 => "lo", 1 => "hi" }
      lo = described_class.new(id: :a, legend: legend, probabilities: { "0" => 0.6, "1" => 0.4 }, confidence: 0.6)
      hi = described_class.new(id: :b, legend: legend, probabilities: { "0" => 0.1, "1" => 0.9 }, confidence: 0.9)
      expect(lo < hi).to be(true)
      expect(hi > 0.5).to be(true)
      expect(0.5 < hi).to be(true) # rubocop:disable Style/YodaCondition
      expect([hi, lo, answer].sort.map(&:id)).to eq(%i[a b severity])
      expect([hi, lo].max).to be(hi)
      expect([hi, lo].sum).to be_within(1e-9).of(1.3)
      expect(hi <=> "hi").to be_nil
      expect(hi.between?(0.5, 1.0)).to be(true)
    end
  end
end
