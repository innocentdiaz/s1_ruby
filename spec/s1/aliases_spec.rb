# frozen_string_literal: true

require "open3"

# Every pre-theory spelling still works, as a plain alias of the theory's name.
RSpec.describe "compatibility aliases" do
  let(:stub) { S1::Providers::Stub.new(noul: 0.9, choice: :b, score: 2, e: 0.8) }
  let(:state) { S1::State.new("x", provider: stub) }
  let(:choice) { S1::Answer::Choice.new(id: :c, choice: "b", probabilities: { "a" => 0.3, "b" => 0.7 }, confidence: 0.7) }
  let(:score) do
    S1::Answer::Score.new(id: :s, legend: { 0 => "lo", 1 => "mid", 2 => "hi" },
                          probabilities: { "1" => 0.5, "2" => 0.5 }, confidence: 0.5)
  end

  def same_method?(object, old, new) = object.method(old) == object.method(new)

  it "S1::Subject is S1::State" do
    expect(S1::Subject).to be(S1::State)
  end

  it "S1::Answer::Base is S1::Distribution" do
    expect(S1::Answer::Base).to be(S1::Distribution)
  end

  it "State#state is State#rendered" do
    expect(state.state).to be(state.rendered)
    expect(same_method?(state, :state, :rendered)).to be(true)
  end

  it "Result#answers is Result#distributions" do
    result = state.measure { |q| q.judge :e, "q?" }
    expect(result.answers).to be(result.distributions)
    expect(same_method?(result, :answers, :distributions)).to be(true)
  end

  it "Question::Choice#options is #categories" do
    q = S1::Question::Choice.new(instructions: "q?", criteria: { a: nil, b: nil })
    expect(q.options).to eq(q.categories)
    expect(same_method?(q, :options, :categories)).to be(true)
  end

  it "Answer::Choice#options is #categories" do
    expect(choice.options).to eq(choice.categories)
    expect(same_method?(choice, :options, :categories)).to be(true)
  end

  it "Answer::Score#score is #expectation" do
    expect(score.score).to eq(score.expectation)
    expect(same_method?(score, :score, :expectation)).to be(true)
  end

  it "config.symbol / symbol= / symbol_name are psi / psi= / psi_name" do
    config = S1::Config.new
    config.symbol = "⍣"
    expect(config.psi).to eq("⍣")
    expect(config.symbol).to eq(config.psi)
    expect(config.symbol_name).to eq(config.psi_name)
    expect(same_method?(config, :symbol, :psi)).to be(true)
    expect(same_method?(config, :symbol=, :psi=)).to be(true)
    expect(same_method?(config, :symbol_name, :psi_name)).to be(true)
  end

  it "Questions#noul is #judge; #choice is gone from the builder, a noun there would yield a distribution" do
    questions = S1::Questions.new
    expect(same_method?(questions, :noul, :judge)).to be(true)
    expect(questions.respond_to?(:choice)).to be(false)
  end

  it "Answer::Score#index is #key, the legacy name for the legend key" do
    expect(score.index).to eq(score.key)
    expect(same_method?(score, :index, :key)).to be(true)
  end

  it "State#ask / #batch / #ask_about are #measure" do
    %i[ask batch ask_about].each { |old| expect(same_method?(state, old, :measure)).to be(true), old.to_s }
    expect(state.ask { |q| q.judge :e, "q?" }.to_h).to eq(state.measure { |q| q.judge :e, "q?" }.to_h)
  end

  it "State#noul is #judge; #noul? / #ask? are #judge?" do
    expect(same_method?(state, :noul, :judge)).to be(true)
    expect(same_method?(state, :noul?, :judge?)).to be(true)
    expect(same_method?(state, :ask?, :judge?)).to be(true)
    expect(state.noul("q?").to_f).to eq(state.judge("q?").to_f)
    expect(state.noul?("q?")).to eq(state.judge?("q?"))
  end

  it "Predicates#noul / #noul? / #ask? are #judge / #judge? / #judge?" do
    p = S1.predicates
    expect(same_method?(p, :noul, :judge)).to be(true)
    expect(same_method?(p, :noul?, :judge?)).to be(true)
    expect(same_method?(p, :ask?, :judge?)).to be(true)
    expect(p.noul("q?")).to eq(p.judge("q?"))
    expect(p.noul?("q?")).to eq(p.judge?("q?"))
  end

  it "Primitives aliases mirror State's" do
    expect(S1::Primitives.instance_method(:noul)).to eq(S1::Primitives.instance_method(:judge))
    expect(S1::Primitives.instance_method(:noul?)).to eq(S1::Primitives.instance_method(:judge?))
    expect(S1::Primitives.instance_method(:ask?)).to eq(S1::Primitives.instance_method(:judge?))
    %i[ask batch ask_about].each do |old|
      expect(S1::Primitives.instance_method(old)).to eq(S1::Primitives.instance_method(:measure)), old.to_s
    end
  end

  it "Providers::Base#answer is #distribution, and build_result takes answers:" do
    provider = S1::Providers::Stub.new
    expect(same_method?(provider, :answer, :distribution)).to be(true)
    noul = provider.send(:answer, :e, S1::Question::Noul.new(instructions: "q?"), probability: 0.4)
    expect(noul).to be_a(S1::Answer::Noul)
    expect(provider.send(:build_result, answers: { e: noul }).distributions).to eq(e: noul)
  end

  it "S1.ask is S1.measure; Client#ask is Client#measure" do
    expect(S1.method(:ask)).to eq(S1.method(:measure))
  end

  it "S1.state is S1::State.new" do
    expect(S1.state("x")).to be_a(S1::State)
    expect(S1.state("x").rendered).to eq("x")
    expect(S1.state("x", threshold: 0.9, owner: :me).threshold).to eq(0.9)
    expect(S1.state("x", threshold: 0.9, owner: :me).options).to eq(owner: :me)
  end

  it "Result is Enumerable: each, size, nouls, choices, scores" do
    result = state.measure do |q|
      q.judge :e, "q?"
      q.choose :c, "q?", a: nil, b: nil
      q.score :s, "q?", "lo", "hi"
    end
    expect(result).to be_a(Enumerable)
    expect(result.size).to eq(3)
    expect(result.each.map(&:first)).to eq(%i[e c s])
    expect(result.map { |id, _| id }).to eq(%i[e c s])
    expect(result.nouls.keys).to eq([:e])
    expect(result.choices.keys).to eq([:c])
    expect(result.scores.keys).to eq([:s])
  end

  it "Answer::Noul#confident? takes the margin, not a threshold, as its positional" do
    noul = S1::Answer::Noul.new(id: :e, probability: 0.85)
    expect(noul.confident?(0.8)).to be(false)
    expect(noul.confident?(0.3)).to be(true)
    expect(noul.confident?(0.3, threshold: 0.8)).to be(false)
    expect(noul.confident?).to eq(!noul.undecided?)
  end

  it "Result takes threshold: on new and with, and reads it back" do
    noul = S1::Answer::Noul.new(id: :e, probability: 0.8)
    result = S1::Result.new(answers: { e: noul, c: choice }, threshold: 0.9)
    expect(result.threshold).to eq(0.9)
    expect(result[:e].threshold).to eq(0.9)
    expect(result.true?(:e)).to be(false)
    expect(result.with(threshold: 0.7).threshold).to eq(0.7)
    expect(result.with(threshold: 0.7).true?(:e)).to be(true)
    expect(result.with(threshold: 0.7).to_h).to eq(result.with_threshold(0.7).to_h)
    expect(S1::Result.new(answers: { e: noul }).threshold).to eq(0.5)
    expect(S1::Result.new(answers: { c: choice }).threshold).to be_nil
    expect(S1::Result.new(answers: { e: noul, f: noul.with(threshold: 0.6) }).threshold).to be_nil
    expect(state.measure { |q| q.judge :e, "q?" }.threshold).to eq(0.5)
    expect(S1::State.new("x", provider: stub, threshold: 0.95).measure { |q| q.judge :e, "q?" }.threshold).to eq(0.95)
  end

  it "Question.choice_options is Question.choice_categories" do
    expect(S1::Question.method(:choice_options)).to eq(S1::Question.method(:choice_categories))
  end

  it "Distribution#type is #kind" do
    expect(same_method?(choice, :type, :kind)).to be(true)
    expect(same_method?(score, :type, :kind)).to be(true)
  end
end
