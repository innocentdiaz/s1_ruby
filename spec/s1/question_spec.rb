# frozen_string_literal: true

RSpec.describe S1::Question do
  describe S1::Question::Noul do
    it "reports its type" do
      expect(described_class.new(instructions: "Is it?").type).to eq("noul")
    end

    it "omits criteria from #to_h when not given" do
      q = described_class.new(instructions: "Is it?")
      expect(q.criteria).to be_nil
      expect(q.to_h).to eq(type: "noul", instructions: "Is it?")
    end

    it "treats empty criteria as omitted" do
      expect(described_class.new(instructions: "Is it?", criteria: {}).criteria).to be_nil
    end

    it "normalizes true:/false: criteria to string keys" do
      q = described_class.new(instructions: "Is it?", criteria: { true: "yes when", false: "no when" })
      expect(q.criteria).to eq("true" => "yes when", "false" => "no when")
      expect(q.to_h).to eq(type: "noul", instructions: "Is it?",
                           criteria: { "true" => "yes when", "false" => "no when" })
    end

    it "accepts a single side" do
      expect(described_class.new(instructions: "Is it?", criteria: { "true" => "yes when" }).criteria)
        .to eq("true" => "yes when")
    end

    it "rejects keys other than true/false" do
      expect { described_class.new(instructions: "Is it?", criteria: { true: "y", maybe: "m" }) }
        .to raise_error(S1::ValidationError, %r{true/false.*maybe})
    end
  end

  describe S1::Question::Choice do
    it "reports its type" do
      expect(described_class.new(instructions: "Which?", criteria: { a: "A", b: "B" }).type).to eq("choice")
    end

    it "stringifies category keys and exposes #categories (#options is the old name)" do
      q = described_class.new(instructions: "Which?", criteria: { returns: "Refunds", billing: "Charges" })
      expect(q.criteria).to eq("returns" => "Refunds", "billing" => "Charges")
      expect(q.categories).to eq(%w[returns billing])
      expect(q.options).to eq(q.categories)
      expect(q.to_h).to eq(type: "choice", instructions: "Which?",
                           criteria: { "returns" => "Refunds", "billing" => "Charges" })
    end

    it "allows nil descriptions" do
      q = described_class.new(instructions: "Which?", criteria: { a: nil, b: nil })
      expect(q.criteria).to eq("a" => nil, "b" => nil)
    end

    it "refuses a String or an Integer as the options, as a ValidationError" do
      ["a,b", 2, :ab].each do |bad|
        expect { described_class.new(instructions: "Which?", criteria: bad) }
          .to raise_error(S1::ValidationError, /choice options must be/), bad.inspect
      end
      expect { S1::State.new("x").choose("q?", categories: "a,b") }.to raise_error(S1::ValidationError, /choice options must be/)
    end

    it "requires at least two options" do
      expect { described_class.new(instructions: "Which?", criteria: { only: "one" }) }
        .to raise_error(S1::ValidationError, /at least 2 options \(got 1\)/)
      expect { described_class.new(instructions: "Which?", criteria: nil) }
        .to raise_error(S1::ValidationError, /got 0/)
    end

    it "carries a nominal S1::Scale, built from the criteria or given as them; criteria stays the wire form" do
      built = described_class.new(instructions: "Which?", criteria: { returns: "Refunds", billing: nil })
      expect(built.scale).to be_a(S1::Scale).and be_nominal
      expect(built.scale).to eq(S1.scale(returns: "Refunds", billing: nil))
      expect(built.scale.definitions).to eq("returns" => "Refunds", "billing" => nil)
      expect(described_class.new(instructions: "Which?", criteria: %w[a b]).scale).to eq(S1.scale("a", "b", ordered: false))
      team = S1.scale(returns: "Refunds", billing: "Charges")
      given = described_class.new(instructions: "Which?", criteria: team)
      expect(given.scale).to be(team)
      expect(given.criteria).to eq("returns" => "Refunds", "billing" => "Charges")
      expect(given.categories).to eq(%w[returns billing])
      expect(given.to_h).to eq(type: "choice", instructions: "Which?", criteria: { "returns" => "Refunds", "billing" => "Charges" })
      expect(S1::Question.from_h(given.to_h)).to eq(given)
      expect(given.with(instructions: "Who?").scale).to eq(team)
    end

    it "refuses an ordinal scale, an unresolved dynamic one, and one with fewer than two categories" do
      expect { described_class.new(instructions: "Which?", criteria: S1.scale("lo", "hi")) }
        .to raise_error(S1::ValidationError, "choice takes a nominal scale (got #<S1::Scale lo < hi>)")
      expect { described_class.new(instructions: "Which?", criteria: S1.scale(:teams)) }
        .to raise_error(S1::ValidationError, /dynamic; resolve it first/)
      expect { described_class.new(instructions: "Which?", criteria: S1.scale(only: "one")) }
        .to raise_error(S1::ValidationError, /at least 2 options \(got 1\)/)
    end
  end

  describe S1::Question::Score do
    it "reports its type" do
      expect(described_class.new(instructions: "How?", criteria: %w[low high]).type).to eq("score")
    end

    it "keeps levels ordered and stringified" do
      q = described_class.new(instructions: "How?", criteria: [:low, "mid", 3])
      expect(q.criteria).to eq(%w[low mid 3])
      expect(q.levels).to eq(%w[low mid 3])
      expect(q.to_h).to eq(type: "score", instructions: "How?", criteria: %w[low mid 3])
    end

    it "requires at least two levels" do
      expect { described_class.new(instructions: "How?", criteria: ["only"]) }
        .to raise_error(S1::ValidationError, /at least 2 ordered levels \(got 1\)/)
      expect { described_class.new(instructions: "How?", criteria: nil) }
        .to raise_error(S1::ValidationError, /got 0/)
    end

    it "carries an ordinal S1::Scale, built from the levels or given as them (alone or as the one level); criteria stays the list" do
      built = described_class.new(instructions: "How?", criteria: %w[low high])
      expect(built.scale).to be_a(S1::Scale).and be_ordinal
      expect(built.scale).to eq(S1.scale("low", "high"))
      severity = S1.scale("low", "mid", "high", name: "Severity")
      given = described_class.new(instructions: "How?", criteria: severity)
      expect(given.scale).to be(severity)
      expect(given.criteria).to eq(%w[low mid high])
      expect(given.levels).to eq(%w[low mid high])
      expect(given.to_h).to eq(type: "score", instructions: "How?", criteria: %w[low mid high])
      expect(S1::Question.from_h(given.to_h)).to eq(given)
      expect(described_class.new(instructions: "How?", criteria: [severity]).scale).to be(severity)
      expect(given.with(instructions: "Bad?").scale).to eq(severity)
    end

    it "shows an ordinal scale's definitions as the levels, and the distribution comes back on the scale, speaking the labels" do
      described = S1.scale({ low: "no impact", high: "no workaround" }, ordered: true)
      question = described_class.new(instructions: "How?", criteria: described)
      expect(question.scale).to be(described)
      expect(question.criteria).to eq(["no impact", "no workaround"])
      expect(question.levels).to eq(["no impact", "no workaround"])
      plain = described_class.new(instructions: "How?", criteria: S1.scale("low", "high"))
      expect(plain.criteria).to eq(%w[low high])
      answer = S1::Answer::Score.new(id: :x, legend: { 0 => "no impact", 1 => "no workaround" }, probabilities: { "1" => 1.0 },
                                     confidence: 1.0, scale: described)
      expect(answer.scale).to be(described)
      expect(answer.level).to eq("high")
      expect(answer.level).to be_high
      expect(answer.levels).to eq(%w[low high])
      stubbed = S1::State.new("t", provider: S1::Providers::Stub.new(score: 1)).score("How?", described)
      expect(stubbed.level).to eq("high")
      expect(stubbed.scale).to be(described)
    end

    it "refuses a Scale beside other levels, a nominal scale, an unresolved dynamic one, and one with fewer than two levels" do
      severity = S1.scale("low", "high")
      expect { described_class.new(instructions: "How?", criteria: [severity, "critical"]) }
        .to raise_error(S1::ValidationError, "score takes a scale or levels, not both (got [#<S1::Scale low < high>, \"critical\"])")
      expect { S1::Questions.new.score(:s, "How?", severity, "critical") }.to raise_error(S1::ValidationError, /not both/)
      expect { S1::Question::Choice.new(instructions: "Which?", criteria: [S1.scale(a: nil, b: nil), "c"]) }
        .to raise_error(S1::ValidationError, /choose takes a scale or categories, not both/)
      expect { described_class.new(instructions: "How?", criteria: S1.scale(a: nil, b: nil)) }
        .to raise_error(S1::ValidationError, "score takes an ordinal scale (got #<S1::Scale a | b>)")
      expect { described_class.new(instructions: "How?", criteria: S1.scale(-> { %w[a b] })) }
        .to raise_error(S1::ValidationError, /dynamic; resolve it first/)
      expect { described_class.new(instructions: "How?", criteria: S1.scale("only")) }
        .to raise_error(S1::ValidationError, /at least 2 ordered levels \(got 1\)/)
    end
  end

  describe "instructions" do
    it "strips String instructions" do
      expect(S1::Question::Noul.new(instructions: "  Is it?  \n").instructions).to eq("Is it?")
    end

    it "rejects blank Strings" do
      expect { S1::Question::Noul.new(instructions: "   ") }
        .to raise_error(S1::ValidationError, /blank/)
    end

    it "passes Hash instructions through untouched" do
      structured = { field: { name: "invoice_number" }, extracted_value: "4471", question: "Does it match?" }
      q = S1::Question::Noul.new(instructions: structured)
      expect(q.instructions).to equal(structured)
      expect(q.to_h[:instructions]).to eq(structured)
    end

    it "rejects other types" do
      expect { S1::Question::Noul.new(instructions: 42) }
        .to raise_error(S1::ValidationError, /String or a Hash \(got Integer\)/)
      expect { S1::Question::Noul.new(instructions: nil) }
        .to raise_error(S1::ValidationError, /got NilClass/)
    end
  end
end

RSpec.describe S1::Questions do
  subject(:questions) { described_class.new }

  it "adds questions in order with symbolized ids" do
    questions.judge("escalate", "Human?")
    questions.choose(:department, "Which?", returns: "R", billing: "B")
    questions.score("severity", "How?", "low", "high")

    expect(questions.to_h.keys).to eq(%i[escalate department severity])
    expect(questions.to_h.values.map(&:class))
      .to eq([S1::Question::Noul, S1::Question::Choice, S1::Question::Score])
    expect(questions.size).to eq(3)
    expect(questions).not_to be_empty
    expect(questions.map { |id, _| id }).to eq(%i[escalate department severity])
  end

  it "turns judge clarification kwargs into criteria" do
    questions.judge(:repeat, "Before?", true: "mentions a ticket", false: "no sign")
    expect(questions.to_h[:repeat].criteria).to eq("true" => "mentions a ticket", "false" => "no sign")
  end

  it "leaves judge criteria nil without clarification" do
    questions.judge(:repeat, "Before?")
    expect(questions.to_h[:repeat].criteria).to be_nil
  end

  it "turns inline category kwargs into criteria" do
    questions.choose(:department, "Which?", returns: "Refunds", billing: nil)
    expect(questions.to_h[:department].criteria).to eq("returns" => "Refunds", "billing" => nil)
  end

  it "takes categories:, choices: or criteria: alike for a choose" do
    questions.choose(:a, "A?", categories: { x: "X", y: "Y" })
    questions.choose(:b, "B?", choices: %w[x y])
    questions.choose(:c, "C?", criteria: { x: nil, y: nil })
    expect(questions.to_h.values.map(&:categories)).to all(eq(%w[x y]))
  end

  it "keeps noul as the alias of judge, and has no choice: every method here adds a question" do
    questions.noul(:n, "N?", true: "t")
    expect(questions.to_h[:n]).to eq(S1::Question::Noul.new(instructions: "N?", criteria: { true: "t" }))
    expect(S1::Questions.new.respond_to?(:choice)).to be(false)
    expect { questions.choice(:c, "C?", x: "X", y: "Y") }.to raise_error(NoMethodError)
  end

  it "takes score levels as varargs" do
    questions.score(:severity, "How?", "Cosmetic", "Degraded", "Blocking")
    expect(questions.to_h[:severity].levels).to eq(%w[Cosmetic Degraded Blocking])
  end

  it "takes a Scale as a score's one level argument, and as a choose's categories:" do
    severity = S1.scale("Cosmetic", "Degraded", "Blocking")
    team = S1.scale(returns: "Refunds", billing: "Charges")
    questions.score(:severity, "How?", severity)
    questions.choose(:team, "Which?", categories: team)
    questions.choose(:team2, "Which?", criteria: team)
    questions.score(:severity2, "How?", criteria: severity)
    expect(questions.to_h[:severity].scale).to be(severity)
    expect(questions.to_h[:severity].levels).to eq(%w[Cosmetic Degraded Blocking])
    expect(questions.to_h[:team].scale).to be(team)
    expect(questions.to_h[:team].categories).to eq(%w[returns billing])
    expect(questions.to_h[:team2].scale).to be(team)
    expect(questions.to_h[:severity2].scale).to be(severity)
    expect { questions.score(:bad, "How?", team) }.to raise_error(S1::ValidationError, /score takes an ordinal scale/)
    expect { questions.choose(:bad, "Which?", categories: severity) }.to raise_error(S1::ValidationError, /choice takes a nominal scale/)
  end

  it "prefers explicit criteria: over kwargs and varargs" do
    questions.judge(:n, "N?", criteria: { true: "explicit" }, false: "kwarg")
    questions.choose(:c, "C?", criteria: { x: "X", y: "Y" }, z: "Z")
    questions.score(:s, "S?", "ignored", "also", criteria: %w[a b])

    expect(questions.to_h[:n].criteria).to eq("true" => "explicit")
    expect(questions.to_h[:c].categories).to eq(%w[x y])
    expect(questions.to_h[:s].levels).to eq(%w[a b])
  end

  it "raises on a duplicate id" do
    questions.noul(:dup, "One")
    expect { questions.noul("dup", "Two") }.to raise_error(S1::ValidationError, /duplicate question id :dup/)
  end

  it "returns self from add for chaining" do
    expect(questions.add(:a, S1::Question::Noul.new(instructions: "A?"))).to be(questions)
  end

  describe ".coerce" do
    let(:noul) { S1::Question::Noul.new(instructions: "A?") }

    it "accepts a Questions" do
      questions.noul(:a, "A?")
      coerced = described_class.coerce(questions)
      expect(coerced.keys).to eq([:a])
      expect(coerced).to be_frozen
    end

    it "accepts a Hash of Question, symbolizing ids" do
      coerced = described_class.coerce("a" => noul)
      expect(coerced).to eq(a: noul)
      expect(coerced).to be_frozen
    end

    it "accepts a block" do
      coerced = described_class.coerce { |q| q.noul(:a, "A?") }
      expect(coerced.keys).to eq([:a])
      expect(coerced[:a]).to be_a(S1::Question::Noul)
    end

    it "asks a Questions or a Hash and a block together" do
      questions.noul(:a, "A?")
      coerced = described_class.coerce(questions) { |q| q.noul(:b, "B?") }
      expect(coerced.keys).to eq(%i[a b])
      expect(described_class.coerce({ "a" => noul }) { |q| q.noul(:b, "B?") }.keys).to eq(%i[a b])
      expect { described_class.coerce(questions) { |q| q.noul(:a, "again?") } }.to raise_error(S1::ValidationError, /duplicate/)
    end

    it "raises when empty" do
      expect { described_class.coerce }.to raise_error(S1::ValidationError, /no questions/)
      expect { described_class.coerce({}) }.to raise_error(S1::ValidationError, /no questions/)
      expect { described_class.coerce { |_q| nil } }.to raise_error(S1::ValidationError, /no questions/)
    end
  end

  describe ".from_h" do
    it "round-trips every type through to_h, with string keys" do
      built = S1::Questions.new
      built.noul(:a, "A?", true: "yes-ish")
      built.choose(:b, "B?", x: "one", y: "two")
      built.score(:c, "C?", "low", "high")
      built.to_h.each_value do |q|
        json = JSON.parse(JSON.generate(q.to_h))
        expect(S1::Question.from_h(json)).to eq(q)
      end
    end

    it "rejects unknown types" do
      expect { S1::Question.from_h(type: "essay", instructions: "x") }.to raise_error(S1::ValidationError, /essay/)
    end
  end
end
