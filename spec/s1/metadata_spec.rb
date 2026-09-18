# frozen_string_literal: true

RSpec.describe "metadata: labels a measurement for the program" do
  let(:requests) { [] }

  before do
    S1.config.provider = S1::Providers::Stub.new
    S1.on_result { |_result, request| requests << request }
  end

  it "is {} on a Request with none" do
    S1::State.new("text").judge("Human?")
    expect(requests.last.metadata).to eq({})
  end

  it "rides on the Request from the State, with symbol keys" do
    S1::State.new("text", metadata: { "call_type" => "routing" }).judge("Human?")
    expect(requests.last.metadata).to eq(call_type: "routing")
  end

  it "rides from a verb, on judge, is?, choose, score, same_as and measure" do
    state = S1::State.new("text")
    state.judge("Human?", metadata: { call_type: "a" })
    state.is?("a greeting", metadata: { call_type: "b" })
    state.choose("Which?", categories: { x: "X", y: "Y" }, metadata: { call_type: "c" })
    state.score("How?", "low", "high", metadata: { call_type: "d" })
    state.same_as("other text", metadata: { call_type: "e" })
    state.measure(metadata: { call_type: "f" }) { |q| q.judge :one, "One?" }

    expect(requests.map { |r| r.metadata[:call_type] }).to eq(%w[a b c d e f])
  end

  it "merges: a later with(metadata:) or a verb's over the State's" do
    state = S1::State.new("text", metadata: { call_type: "routing", firm: 1 }).with(metadata: { firm: 2 })
    state.judge("Human?", metadata: { job: "abc" })
    expect(requests.last.metadata).to eq(call_type: "routing", firm: 2, job: "abc")
  end

  it "carries through a lens" do
    S1::State.new("text", metadata: { call_type: "pre_score" }).given(policy: "p").judge("Within `policy`?")
    expect(requests.last.metadata).to eq(call_type: "pre_score")
  end

  it "is not a question id, a clarification or a category" do
    S1::State.new("text").choose("Which?", x: "X", y: "Y", metadata: { call_type: "c" })
    expect(requests.last.questions.keys).to eq([:choice])
    expect(requests.last.questions[:choice].to_h.to_s).not_to include("metadata")
  end

  it "holds JSON's values only" do
    expect { S1::State.new("text", metadata: "routing") }.to raise_error(S1::ValidationError, /is a Hash/)
    expect { S1::State.new("text", metadata: { owner: Object.new }) }.to raise_error(S1::ValidationError, /metadata\[:owner\] is a Object/)
    expect { S1::State.new("text", metadata: { 1 => "x" }) }.to raise_error(S1::ValidationError, /keys are Strings or Symbols/)
    expect(S1::State.new("text", metadata: { tags: [1, "a", nil], nested: { ok: true } }).options[:metadata])
      .to eq(tags: [1, "a", nil], nested: { ok: true })
  end

  it "is never sent to the provider" do
    S1.config.provider = :typesafe
    S1.config.typesafe.api_key = "sk-test"
    stub_request(:post, "https://api.typesafe.ai/v1/systemone").to_return(
      status: 200, headers: { "Content-Type" => "application/json" },
      body: JSON.generate(model: "jev-latest", usage: {}, answers: { noul: { noul: 0.9 } })
    )

    S1::State.new("text", metadata: { call_type: "routing" }).judge("Human?")

    expect(WebMock).to(have_requested(:post, "https://api.typesafe.ai/v1/systemone").with { |req| !req.body.include?("routing") })
  end
end
