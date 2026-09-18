# frozen_string_literal: true

require "s1/rspec"

RSpec.describe S1::Providers::Protocol do
  let(:url) { "http://127.0.0.1:8090/v1/systemone" }
  let(:answers) do
    { yes: { noul: 0.8 },
      which: { choice: "b", probabilities: { a: 0.1, b: 0.8, c: 0.1 }, confidence: 0.8 },
      how: { score: 1.1, probabilities: { "0" => 0.2, "1" => 0.6, "2" => 0.2 }, confidence: 0.6 } }
  end

  before do
    S1.config.protocol.base_url = "http://127.0.0.1:8090"
    stub_request(:post, url).to_return(
      status: 200, headers: { "Content-Type" => "application/json" },
      body: JSON.generate(model: "local", usage: { input_tokens: 12, output_tokens: 0 }, answers: answers)
    )
  end

  it_behaves_like "an S1 provider", -> { S1::Providers::Protocol.new }

  it "reads its address, key and model from the section, which defaults to the environment" do
    expect(described_class.new.name).to eq(:protocol)
    expect(described_class.settings_name).to eq(:protocol)
    S1.reset_config!
    expect(S1.config.protocol.to_h).to eq(base_url: ENV.fetch("S1_BASE_URL", nil), path: ENV.fetch("S1_PATH", "/v1/systemone"),
                                          api_key: ENV.fetch("S1_API_KEY", nil), model: ENV.fetch("S1_MODEL", nil),
                                          max_retries: 2)
  end

  it "POSTs to a configured or explicit path on the same origin" do
    configured = stub_request(:post, "http://127.0.0.1:8090/sysone").to_return(status: 200, body: JSON.generate(answers: answers))
    explicit = stub_request(:post, "http://127.0.0.1:8090/api/decide").to_return(status: 200, body: JSON.generate(answers: answers))

    S1.config.protocol.path = "/sysone"
    S1::State.new("text", provider: :protocol).measure { |q| q.score :how, "How?", "low", "mid", "high" }
    S1::State.new("text", provider: described_class.new(path: "/api/decide")).measure { |q| q.score :how, "How?", "low", "mid", "high" }

    expect(configured).to have_been_requested
    expect(explicit).to have_been_requested
    expect(a_request(:post, url)).not_to have_been_made
  end

  it "POSTs the contract to the configured origin and sends a bearer token only when a key is set" do
    S1.config.protocol.model = "jevk5"
    S1.config.protocol.api_key = "secret"
    result = S1::State.new("text", provider: :protocol).measure { |q| q.score :how, "How?", "low", "mid", "high" }

    expect(WebMock).to(have_requested(:post, url).with do |req|
      body = JSON.parse(req.body)
      req.headers["Authorization"] == "Bearer secret" && body["model"] == "jevk5" && body["state"] == "text"
    end)
    expect(result.provider).to eq(:protocol)
    expect(result[:how].level).to eq("mid")
  end

  it "omits the Authorization header and sends a null model when neither is set" do
    S1::State.new("text", provider: :protocol).measure { |q| q.score :how, "How?", "low", "mid", "high" }

    expect(WebMock).to(have_requested(:post, url).with do |req|
      !req.headers.key?("Authorization") && JSON.parse(req.body)["model"].nil?
    end)
  end

  it "refuses to call when no address is configured" do
    S1.config.protocol.base_url = nil
    request = S1::Request.new(state: "text", questions: {}, model: nil, timeout: 1, options: {})

    expect { described_class.new.call(request) }.to raise_error(S1::InvalidRequestError, /no base_url/)
    expect(a_request(:post, url)).not_to have_been_made
  end

  it "names itself in errors and log lines" do
    stub_request(:post, url).to_return(status: 400, body: JSON.generate(detail: "bad model"))
    logger = double
    expect(logger).to receive(:debug) { |&block| expect(block.call).to start_with("[s1:protocol] POST") }

    caller = described_class.new(logger: logger, max_retries: 0)
    expect { S1::State.new("text", provider: caller).judge?("q?") }
      .to raise_error(S1::InvalidRequestError, "protocol 400: bad model")
  end
end
