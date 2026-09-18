# frozen_string_literal: true

RSpec.describe S1::Providers::Stub do
  let(:questions) do
    S1::Questions.coerce do |q|
      q.judge  :escalate, "Human?"
      q.choose :department, "Which?", returns: "R", billing: "B", shipping: "S"
      q.score  :severity, "How?", "Cosmetic", "Degraded", "Blocking"
    end
  end
  let(:request) { S1::Request.new(state: "text", questions: questions, model: "m") }

  it "names itself" do
    expect(described_class.new.name).to eq(:stub)
  end

  it "returns a Result with model stub, provider :stub and zero usage" do
    result = described_class.new.call(request)
    expect(result).to be_a(S1::Result)
    expect(result.model).to eq("stub")
    expect(result.provider).to eq(:stub)
    expect(result.usage).to eq(input_tokens: 0, output_tokens: 0)
    expect(result.input_tokens).to eq(0)
    expect(result.distributions.keys).to eq(%i[escalate department severity])
  end

  describe "neutral defaults" do
    let(:result) { described_class.new.call(request) }

    it "answers a noul at 0.5" do
      expect(result[:escalate].to_f).to eq(0.5)
    end

    it "picks the first option at 1.0" do
      choice = result[:department]
      expect(choice.to_sym).to eq(:returns)
      expect(choice.probabilities).to eq("returns" => 1.0, "billing" => 0.0, "shipping" => 0.0)
      expect(choice.confidence).to eq(1.0)
    end

    it "picks the first level at 1.0" do
      score = result[:severity]
      expect(score.key).to eq(0)
      expect(score.level).to eq("Cosmetic")
      expect(score.to_f).to eq(0.0)
      expect(score.levels).to eq(%w[Cosmetic Degraded Blocking])
      expect(score.probabilities).to eq("0" => 1.0, "1" => 0.0, "2" => 0.0)
      expect(score.confidence).to eq(1.0)
    end
  end

  describe "shorthand values" do
    it "takes a float for a noul" do
      result = described_class.new("escalate" => 0.9).call(request)
      expect(result[:escalate].to_f).to eq(0.9)
      expect(result[:escalate].probabilities["false"]).to be_within(1e-9).of(0.1)
    end

    it "takes a symbol or string for a choice" do
      expect(described_class.new(department: :billing).call(request)[:department].to_s).to eq("billing")
      shipping = described_class.new(department: "shipping").call(request)[:department]
      expect(shipping.to_sym).to eq(:shipping)
      expect(shipping[:shipping]).to eq(1.0)
      expect(shipping[:returns]).to eq(0.0)
    end

    it "takes an integer index for a score" do
      score = described_class.new(severity: 2).call(request)[:severity]
      expect(score.key).to eq(2)
      expect(score.level).to eq("Blocking")
      expect(score.to_f).to eq(2.0)
      expect(score.probabilities).to eq("0" => 0.0, "1" => 0.0, "2" => 1.0)
    end
  end

  it "rejects a score outside the question's levels, naming the id and the range" do
    expect { described_class.new(severity: 3).call(request) }
      .to raise_error(S1::ValidationError, "stub score for :severity is 3; the level position must be in 0...3")
    expect { described_class.new(severity: -1).call(request) }.to raise_error(S1::ValidationError, /:severity is -1/)
    expect { described_class.new { { severity: 7 } }.call(request) }.to raise_error(S1::ValidationError, /in 0\.\.\.3/)
    expect(described_class.new(severity: 2).call(request)[:severity].level).to eq("Blocking")
  end

  it "takes a score by its level's label, and rejects a label or a fractional position off the scale" do
    expect(described_class.new(severity: "Blocking").call(request)[:severity].level).to eq("Blocking")
    expect(described_class.new(severity: :Degraded).call(request)[:severity].key).to eq(1)
    expect(described_class.new(severity: 2.0).call(request)[:severity].key).to eq(2)
    expect { described_class.new(severity: "high").call(request) }
      .to raise_error(S1::ValidationError, 'stub score for :severity is "high"; must be one of ["Cosmetic", "Degraded", "Blocking"]')
    expect { described_class.new(severity: :low).call(request) }.to raise_error(S1::ValidationError, /:severity is :low/)
    expect { described_class.new(severity: 1.7).call(request) }.to raise_error(S1::ValidationError, /:severity is 1\.7; the level position/)
  end

  it "takes a score on a described scale by its label, by Scale[:label] or by the text shown" do
    described = S1.scale({ cosmetic: "Looks off", degraded: "Slow", blocking: "No workaround" }, ordered: true)
    ask = S1::Request.new(state: "t", questions: S1::Questions.coerce { |q| q.score :severity, "How?", described }, model: "m")
    expect(described_class.new(severity: "degraded").call(ask)[:severity].level).to be_degraded
    expect(described_class.new(severity: described[:blocking]).call(ask)[:severity].level).to eq(described[:blocking])
    expect(described_class.new(severity: "Slow").call(ask)[:severity].level.scale).to be(described)
    expect { described_class.new(severity: "high").call(ask) }
      .to raise_error(S1::ValidationError, 'stub score for :severity is "high"; must be one of ["cosmetic", "degraded", "blocking"] ' \
                                           '(shown as ["Looks off", "Slow", "No workaround"])')
  end

  it "rejects a noul outside 0..1, so a typo never yields mass outside the scale" do
    expect { described_class.new(escalate: 9).call(request) }
      .to raise_error(S1::ValidationError, "stub noul for :escalate is 9; the probability must be in 0.0..1.0")
    expect { described_class.new(escalate: -0.1).call(request) }.to raise_error(S1::ValidationError, /:escalate is -0\.1/)
    expect { described_class.new(escalate: :yes).call(request) }.to raise_error(S1::ValidationError, /:escalate is :yes/)
    expect(described_class.new(escalate: 1).call(request)[:escalate].to_f).to eq(1.0)
    expect(described_class.new(escalate: 0).call(request)[:escalate].to_f).to eq(0.0)
    expect(described_class.new(escalate: "0.25").call(request)[:escalate].to_f).to eq(0.25)
  end

  it "rejects a choice off the question's scale, naming the id and the categories" do
    expect { described_class.new(department: :zzz).call(request) }
      .to raise_error(S1::ValidationError, 'stub choice for :department is :zzz; must be one of ["returns", "billing", "shipping"]')
    expect { described_class.new { { department: "nope" } }.call(request) }.to raise_error(S1::ValidationError, /:department is "nope"/)
    expect(described_class.new(department: "shipping").call(request)[:department].to_sym).to eq(:shipping)
  end

  describe "full-hash values" do
    it "passes noul fields through" do
      result = described_class.new(escalate: { "probability" => 0.33 }).call(request)
      expect(result[:escalate].to_f).to eq(0.33)
    end

    it "passes choice fields through" do
      choice = described_class.new(
        department: { choice: :billing, probabilities: { returns: 0.2, billing: 0.7, shipping: 0.1 }, confidence: 0.7 }
      ).call(request)[:department]
      expect(choice.to_sym).to eq(:billing)
      expect(choice[:billing]).to eq(0.7)
      expect(choice.confidence).to eq(0.7)
    end

    it "passes score fields through and derives the expectation; a score: or expectation: in the hash is not the wire's number" do
      score = described_class.new(
        severity: { score: 0.0, legend: { 0 => "Cosmetic", 1 => "Degraded", 2 => "Blocking" },
                    probabilities: { "0" => 0.1, "1" => 0.4, "2" => 0.5 }, confidence: 0.5 }
      ).call(request)[:severity]
      expect(score.to_f).to be_within(1e-9).of(1.4)
      expect(score.expectation).to be_within(1e-9).of(1.4)
      expect(score.key).to eq(2)
      expect(score.level).to eq("Blocking")
      expect(score.confidence).to eq(0.5)
      named = described_class.new(
        severity: { expectation: 0.2, legend: { 0 => "Cosmetic", 1 => "Degraded", 2 => "Blocking" }, probabilities: { "0" => 1.0 },
                    confidence: 1 }
      ).call(request)[:severity]
      expect(named.expectation).to eq(0.0)
      off = { legend: { 0 => "a", 1 => "b", 2 => "c" }, probabilities: { "0" => 1.0 }, confidence: 1 }
      expect { described_class.new(severity: off).call(request) }
        .to raise_error(S1::ValidationError, ':severity: the legend ["a", "b", "c"] is not #<S1::Scale Cosmetic < Degraded < Blocking>')
      one_hot = described_class.new(severity: 2).call(request)[:severity]
      expect(one_hot.expectation).to eq(2.0)
      expect(one_hot.raw).to be_nil
    end

    it "keeps a full-fields Hash as the distribution's raw, so a score: or expectation: in it is still there to read" do
      fields = { score: 0.1, legend: { 0 => "Cosmetic", 1 => "Degraded", 2 => "Blocking" }, probabilities: { "0" => 0.3, "1" => 0.7 },
                 confidence: 0.7 }
      score = described_class.new(severity: fields).call(request)[:severity]
      expect(score.raw).to eq(fields)
      expect(score.raw[:score]).to eq(0.1)
      expect(score.expectation).to be_within(1e-9).of(0.7)
      noul = described_class.new(escalate: { probability: 0.8 }).call(request)[:escalate]
      expect(noul.raw).to eq(probability: 0.8)
      choice = described_class.new(department: { choice: :billing, probabilities: { "billing" => 0.6, "shipping" => 0.4 }, confidence: 0.6,
                                                 raw: "theirs" }).call(request)[:department]
      expect(choice.raw).to eq("theirs")
    end
  end

  describe "block form" do
    it "receives the Request and its map wins over canned answers" do
      seen = nil
      stub = described_class.new(escalate: 0.1) do |req|
        seen = req
        { escalate: 0.8, department: :shipping }
      end

      result = stub.call(request)

      expect(seen).to be(request)
      expect(result[:escalate].to_f).to eq(0.8)
      expect(result[:department].to_sym).to eq(:shipping)
      expect(result[:severity].key).to eq(0)
    end

    it "tolerates a block returning nil" do
      result = described_class.new(escalate: 0.1) { nil }.call(request)
      expect(result[:escalate].to_f).to eq(0.1)
    end
  end
end
