# frozen_string_literal: true

RSpec.describe S1::Predicate do
  let(:p) { S1.predicates }
  let(:calls) { ["angry about a bill", "calm return", "angry return", "bill question"] }

  before do
    S1.config.provider = S1::Providers::Stub.new do |req|
      s = req.state.to_s
      { noul: s.include?("angry") ? 0.9 : 0.1, choice: s.include?("bill") ? :billing : :returns, score: s.length % 3 }
    end
  end

  it "filters, counts and greps with a boolean predicate" do
    angry = p.is?("an angry customer")
    expect(calls.select(&angry)).to eq(["angry about a bill", "angry return"])
    expect(calls.grep(angry)).to eq(["angry about a bill", "angry return"])
    expect(calls.count(&p.judge?("angry"))).to eq(2)
    expect(calls.partition(&p.ask?("angry")).last).to eq(["calm return", "bill question"])
  end

  it "groups by a choice and sorts by a score" do
    expect(calls.group_by(&p.choice("Which team?", returns: "r", billing: "b")))
      .to eq(billing: ["angry about a bill", "bill question"], returns: ["calm return", "angry return"])
    expect(calls.min_by(&p.score("How severe?", "low", "mid", "high"))).to eq("angry about a bill")
    expect(calls.max_by(&p.score("How severe?", "low", "mid", "high"))).to eq("calm return")
  end

  it "yields one distribution per element for a verb, the thing named for a noun, a boolean for a ?" do
    expect(calls.map(&p.judge("angry"))).to all(be_a(S1::Answer::Noul))
    expect(calls.map(&p.judge("angry")).first.collapse).to be(true)
    expect(calls.map(&p.is("angry")).map(&:to_f)).to eq([0.9, 0.1, 0.9, 0.1])
    expect(calls.map(&p.choose("Which team?", returns: "r", billing: "b"))).to all(be_a(S1::Answer::Choice))
    expect(calls.map(&p.choice("Which team?", returns: "r", billing: "b"))).to eq(%i[billing returns returns billing])
    expect(calls.map(&p.score("How severe?", "low", "mid", "high"))).to all(be_a(S1::Answer::Score))
    expect(calls.map(&p.level("How severe?", "low", "mid", "high"))).to all(be_a(S1::Level))
    expect(calls.map(&p.judge?("angry"))).to eq([true, false, true, false])
    expect(calls.map(&p.is?("angry"))).to eq([true, false, true, false])
    expect(calls.group_by(&p.choose("Which team?", returns: "r", billing: "b")).keys).to all(be_a(S1::Answer::Choice))
    expect(calls.group_by(&p.choose("Which team?", returns: "r", billing: "b")).size).to eq(2)
  end

  it "sorts by a score's expected position, not its label's alphabet" do
    severity = p.score("How severe?", "low", "mid", "high")
    expect(calls.sort_by(&severity).last(2)).to eq(["bill question", "calm return"])
    expect(calls.map(&severity).map(&:level)).to eq(%w[low high low mid])
    expect(calls.map(&p.level("How severe?", "low", "mid", "high"))).to eq(%w[low high low mid])
    expect(calls.group_by(&p.level("How severe?", "low", "mid", "high")).keys).to eq(%w[low high mid])
    expect(calls.group_by(&p.level("How severe?", "low", "mid", "high"))["high"]).to eq(["calm return"])
  end

  it "sums calibrated probabilities into an expected count" do
    expect(calls.sum(&p.judge("angry"))).to eq(2.0)
    expect(calls.sum(&p.is("angry"))).to eq(2.0)
  end

  it "is measures (the noul) and is? collapses (a boolean), as on a State" do
    expect(p.is("angry")["angry return"]).to be_a(S1::Answer::Noul)
    expect(p.is("angry")["angry return"]).to eq(0.9)
    expect(p.is("angry").measure("angry return")).to be_a(S1::Answer::Noul)
    expect(p.is?("angry")["angry return"]).to be(true)
    expect(p.is?("angry")["calm return"]).to be(false)
    expect(calls.select(&p.is("angry"))).to eq(calls) # a probability is always truthy: the verb is the wrong slot
    expect(calls.select(&p.is?("angry"))).to eq(["angry about a bill", "angry return"])
  end

  it "judges each element under the lens in given:" do
    seen = []
    S1.config.provider = S1::Providers::Stub.new { |req| seen << req.state and { noul: req.state[:this].include?("bill") ? 0.9 : 0.1 } }
    qualified = p.is?("about the same thing as `topic`", given: { topic: "billing" })
    expect(calls.select(&qualified)).to eq(["angry about a bill", "bill question"])
    expect(seen.first).to eq(this: "angry about a bill", topic: "billing")
  end

  it "applies to one state with [] and gives the un-collapsed distribution with #measure" do
    team = p.choice("Which team?", returns: "r", billing: "b")
    expect(team["angry about a bill"]).to be(:billing)
    expect(team.call("calm return")).to be(:returns)
    expect(team.measure("angry about a bill")).to be_a(S1::Answer::Choice)
    expect(team.measure("angry about a bill").probabilities.keys).to eq(%w[returns billing])
    expect(calls.group_by(&team).keys).to eq(%i[billing returns])
    expect(p.choose("Which team?", returns: "r", billing: "b")["angry about a bill"]).to be_a(S1::Answer::Choice)
  end

  it "measures the distribution under every name: the noun's and the ?'s too" do
    expect(p.is?("angry").measure("angry return")).to be_a(S1::Answer::Noul)
    expect(p.judge?("angry").measure("angry return").undecided?).to be(false)
    expect(p.noul?("angry").measure("angry return").to_f).to eq(0.9)
    expect(p.choice("Which team?", returns: "r", billing: "b").measure("bill")).to be_a(S1::Answer::Choice)
    expect(p.level("How severe?", "low", "mid", "high").measure("x")).to be_a(S1::Answer::Score)
    S1.config.provider = S1::Providers::Stub.new { |req| { noul: req.state[:this].include?("bill") ? 0.9 : 0.1 } }
    expect(p.same_as?("a billing call").measure("bill question")).to be_a(S1::Answer::Noul)
  end

  it "collapses a ? at its threshold:, which never reaches the verb" do
    strict = p.is?("angry", threshold: 0.95)
    expect(strict["angry return"]).to be(false)
    expect(strict.measure("angry return").to_f).to eq(0.9)
    expect(p.judge?("angry", threshold: 0.8)["angry return"]).to be(true)
    expect(p.same_as?("angry", threshold: 0.95).measure("x")).to be_a(S1::Answer::Noul)
  end

  it "chooses among the evidence under a lens" do
    seen = nil
    S1.config.provider = S1::Providers::Stub.new { |req| seen = req and { choice: :Bob } }
    skilled = p.choose("the most skilled at `role`", given: { role: "chef" })
    expect(skilled.measure(%w[Michael Bob Dana]).categories).to eq(%i[Michael Bob Dana])
    expect(seen.state).to eq(this: %w[Michael Bob Dana], role: "chef")
    expect(p.choice("the most skilled at `role`", given: { role: "chef" })[%w[Michael Bob Dana]]).to be(:Bob)
  end

  it "carries options through to the state" do
    expect(calls.count(&p.is?("angry", threshold: 0.95))).to eq(0)
    expect { p.is("angry", threshold: 0.95)["x"] }.to raise_error(ArgumentError, /threshold: only applies to a collapse/)
  end

  it "refuses threshold: on a noun as a State does, since only a ? collapses at one" do
    message = /threshold: only applies to a collapse/
    expect { p.choice("?", a: nil, b: nil, threshold: 0.2)["x"] }.to raise_error(ArgumentError, message)
    expect { p.level("?", "lo", "hi", threshold: 0.2)["x"] }.to raise_error(ArgumentError, message)
    expect { p.choose("?", a: nil, b: nil, threshold: 0.2).measure("x") }.to raise_error(ArgumentError, message)
    expect { p.same_as("x", threshold: 0.2)["x"] }.to raise_error(ArgumentError, message)
    expect(p.same_as?("angry", threshold: 0.95)["angry return"]).to be(false)
    expect(p.judge?("angry", threshold: 0.8)["angry return"]).to be(true)
  end

  it "has the verb same_as beside same_as?, a noul per element" do
    S1.config.provider = S1::Providers::Stub.new { |req| { noul: req.state[:this].include?("bill") ? 0.9 : 0.1 } }
    expect(p.same_as("a billing call")["bill question"]).to be_a(S1::Answer::Noul)
    expect(p.same_as("a billing call")["bill question"].to_f).to eq(0.9)
    expect(calls.sum(&p.same_as("a billing call"))).to eq(2.0)
    expect(p.same_as("a billing call").measure("calm return").to_f).to eq(0.1)
    expect(calls.select(&p.same_as("a billing call"))).to eq(calls)
  end

  it "asks about elements with same_as?" do
    S1.config.provider = S1::Providers::Stub.new { |req| { noul: req.state[:this].include?("bill") ? 0.9 : 0.1 } }
    expect(calls.select(&p.same_as?("a billing call"))).to eq(["angry about a bill", "bill question"])
  end

  it "is what ψ returns with no argument" do
    expect(described_class).to be_a(Class)
    expect(S1.predicates.is?("x")).to be_a(described_class)
  end

  it "mirrors State's names: verbs measure, nouns name, ? collapses" do
    expect(p.judge("angry").measure("angry return")).to be_a(S1::Answer::Noul)
    expect(p.noul("angry").measure("angry return")).to be_a(S1::Answer::Noul)
    expect(p.judge?("angry")["angry return"]).to be(true)
    expect(p.noul?("angry")["angry return"]).to be(true)
    expect(p.ask?("angry")["angry return"]).to be(true)
    expect(p.choose("Which team?", returns: "r", billing: "b").measure("bill")).to be_a(S1::Answer::Choice)
    expect(p.choice("Which team?", returns: "r", billing: "b")["bill"]).to be(:billing)
    expect(p.score("How severe?", "low", "mid", "high").measure("x")).to be_a(S1::Answer::Score)
    expect(p.level("How severe?", "low", "mid", "high")["x"]).to be_a(S1::Level)
    expect(p.choose("Which team?", categories: { returns: "r", billing: "b" })["bill"].collapse).to be(:billing)
  end
end
