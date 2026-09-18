# frozen_string_literal: true

# The provider conformance suite, for any gem that implements one:
#
#   require "s1/rspec"
#   RSpec.describe MyProvider do
#     it_behaves_like "an S1 provider", -> { MyProvider.new(api_key: "test") }
#   end
#
# The block builds a provider that can answer without the network (a stubbed
# HTTP client, a fake sidecar). Pass `supports:` when it answers only some
# question kinds.
RSpec.shared_examples "an S1 provider" do |build, supports: %i[noul choice score]|
  let(:provider) { instance_exec(&build) }
  let(:questions) do
    S1::Questions.new.tap do |q|
      q.judge  :yes, "Is it?" if supports.include?(:noul)
      q.choose :which, "Which?", a: "one", b: "two", c: "three" if supports.include?(:choice)
      q.score  :how, "How much?", "low", "mid", "high" if supports.include?(:score)
    end.to_h
  end
  let(:request) { S1::Request.new(state: "some text", questions: questions, model: nil, timeout: 30) }
  let(:result) { provider.call(request) }

  it "returns a Result — a Collapsable — tagged with its name" do
    expect(result).to be_a(S1::Result)
    expect(result).to be_a(S1::Collapsable)
    expect(result.provider).to eq(provider.name)
  end

  it "answers every question, by id, with the distribution kind its scale demands" do
    expect(result.distributions.keys).to match_array(questions.keys)
    questions.each do |id, question|
      klass = { "noul" => S1::Answer::Noul, "choice" => S1::Answer::Choice, "score" => S1::Answer::Score }.fetch(question.type)
      expect(result[id]).to be_a(klass)
      expect(result[id]).to be_a(S1::Distribution)
      expect(result[id].id).to eq(id)
      expect(result[id].kind).to eq(question.type)
    end
  end

  it "keeps probabilities as probabilities" do
    result.distributions.each_value do |d|
      expect(d.probabilities.values).to all(be_between(0.0, 1.0))
      expect(d.probabilities.values.sum).to be_within(0.02).of(1.0)
    end
  end

  it "keys a choice's distribution by its categories and a score's by rank, whatever keys the wire used" do
    expect(result[:which].probabilities.keys).to match_array(%w[a b c]) if supports.include?(:choice)
    expect(result[:how].probabilities.keys).to match_array(%w[0 1 2]) if supports.include?(:score)
    expect(result[:how].levels).to eq(%w[low mid high]) if supports.include?(:score)
    expect(result[:how].key).to eq(result[:how].level.position) if supports.include?(:score)
  end

  it "gives every distribution the scale of its question" do
    expect(result[:yes].scale).to eq([true, false]) if supports.include?(:noul)
    expect(result[:which].scale).to be_a(S1::Scale).and eq(questions[:which].scale) if supports.include?(:choice)
    expect(result[:which].scale.to_a).to eq(questions[:which].categories.map(&:to_sym)) if supports.include?(:choice)
    expect(result[:how].scale).to be_a(S1::Scale).and eq(questions[:how].scale) if supports.include?(:score)
    expect(result[:how].scale.labels).to eq(questions[:how].levels) if supports.include?(:score)
    expect(result[:how].levels).to all(be_a(S1::Level)) if supports.include?(:score)
    expect(result[:how].level.scale).to eq(result[:how].scale) if supports.include?(:score)
  end

  it "collapses" do
    expect(result[:yes].collapse).to be(true).or be(false) if supports.include?(:noul)
    expect(%i[a b c]).to include(result[:which].collapse) if supports.include?(:choice)
    expect(0..2).to cover(result[:how].collapse) if supports.include?(:score)
    expect(result[:how].collapse).to be_a(S1::Level) if supports.include?(:score)
  end

  it "declares what it does not support, so measure refuses before calling" do
    %i[noul choice score].each do |type|
      q = { noul: S1::Question::Noul.new(instructions: "q?"),
            choice: S1::Question::Choice.new(instructions: "q?", criteria: { a: nil, b: nil }),
            score: S1::Question::Score.new(instructions: "q?", criteria: %w[x y]) }.fetch(type)
      expect(provider.supports?(q)).to eq(supports.include?(type))
    end
  end

  it "usage, when reported, is integers" do
    expect(result.usage.values).to all(be_a(Integer))
  end
end
