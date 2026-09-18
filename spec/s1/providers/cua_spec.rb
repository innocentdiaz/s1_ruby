# frozen_string_literal: true

require "tempfile"

RSpec.describe S1::Providers::Cua do
  subject(:provider) do
    described_class.new(checkpoint: "fake.safetensors", python: RbConfig.ruby,
                        script: File.expand_path("../../support/fake_cua_sidecar.rb", __dir__))
  end

  after { provider.close }

  let(:context) { "TASK fill the form\nELEMENT Edit \"Phone number\" value=\"\"" }

  it "answers a choice with one probability per option, the argmax as the pick" do
    result = S1::State.new(context, provider: provider).measure do |q|
      q.choose :fill_with, "Which entity?", phone: "555-0100", email: "a@b.c", skip: nil
    end
    answer = result[:fill_with]
    expect(answer.to_sym).to eq(:phone)
    expect(answer.probabilities.keys).to eq(%w[phone email skip])
    expect(answer.probabilities.values.sum).to be_within(0.01).of(1.0)
    expect(answer.confidence).to eq(answer.probabilities["phone"])
    expect(result.provider).to eq(:cua)
    expect(provider.config["context_tokens"]).to eq(224)
  end

  it "translates option descriptions into option text and reuses the sidecar" do
    state = S1::State.new(context, provider: provider)
    2.times { state.choose("Which?", phone: "555-0100", skip: nil) }
    expect(state.choose("Which?", categories: %w[phone skip]).to_sym).to eq(:phone)
  end

  it "refuses noul and score before calling, as UnsupportedError" do
    state = S1::State.new(context, provider: provider)
    expect { state.judge?("Is this a phone field?") }.to raise_error(S1::UnsupportedError, /cua cannot answer a noul/)
    expect { state.score("How?", "a", "b") }.to raise_error(S1::UnsupportedError, /score/)
    expect(S1::UnsupportedError.ancestors).to include(S1::PermanentError)
  end

  it "enforces the model's context limit on the whole context, instructions included" do
    state = S1::State.new("x" * 300, provider: provider)
    expect { state.choose("Which?", a: nil, b: nil) }.to raise_error(S1::ValidationError, /224 bytes/)
    fits = S1::State.new("x" * 200, provider: provider)
    expect(fits.choose("Which?", a: nil, b: nil)).to be_a(S1::Answer::Choice)
    expect { fits.choose("Which of these, please?", a: nil, b: nil) }.to raise_error(S1::ValidationError, /224 bytes \(got 229\)/)
  end

  it "sends the concept in the checkpoint's own shape: a TASK line the instructions lead, so two questions on one state differ" do
    log = Tempfile.new("cua-contexts")
    ENV["FAKE_CUA_LOG"] = log.path
    element = "ELEMENT Edit \"Phone number\" value=\"\""
    state = S1::State.new(element, provider: provider)
    expect(state.choose("phone", phone: "555-0100", email: "a@b.c").to_sym).to eq(:phone)
    expect(state.choose("email", phone: "555-0100", email: "a@b.c").to_sym).to eq(:email)
    S1::State.new({ element: "Phone number" }, provider: provider).choose({ field: "email" }, phone: nil, email: nil)
    S1::State.new(context, provider: provider).choose("Which entity?", phone: nil, email: nil)
    S1::State.new("TASK fill the form", provider: provider).choose("Which entity?", phone: nil, email: nil)
    contexts = log.read.lines.map { |l| JSON.parse(l) }
    expect(contexts).to eq(["TASK phone\n#{element}", "TASK email\n#{element}",
                            "TASK {\"field\":\"email\"}\n{\"element\":\"Phone number\"}",
                            "TASK fill the form; Which entity?\n#{element}",
                            "TASK fill the form; Which entity?"])
    expect(contexts).to all(satisfy { |c| c.scan("TASK ").one? })
  ensure
    ENV.delete("FAKE_CUA_LOG")
    log&.close!
  end

  it "serializes structured state as JSON context" do
    result = S1::State.new({ element: "Phone number" }, provider: provider).choose("Which?", phone: nil, email: nil)
    expect(result.to_sym).to eq(:phone)
  end

  it "reads checkpoint, python and device from S1.config.cua when not given" do
    S1.config.cua.checkpoint = "from-config"
    S1.config.cua.python = RbConfig.ruby
    S1.config.cua.device = "cpu"
    configured = described_class.new(script: File.expand_path("../../support/fake_cua_sidecar.rb", __dir__))
    expect(S1::State.new(context, provider: configured).choose("Which?", phone: nil, skip: nil).to_sym).to eq(:phone)
    expect(configured.config["checkpoint"]).to eq("from-config")
  ensure
    configured&.close
  end

  it "refuses to boot without a checkpoint" do
    expect { S1::State.new(context, provider: described_class.new).choose("?", a: nil, b: nil) }
      .to raise_error(S1::InvalidRequestError, "no checkpoint: set S1.config.cua.checkpoint")
  end

  it "maps a dead sidecar to ConnectionError" do
    dead = described_class.new(checkpoint: "x", python: RbConfig.ruby, script: "-e", device: "exit 1")
    expect { S1::State.new("ctx", provider: dead).choose("?", a: nil, b: nil) }.to raise_error(S1::ConnectionError)
  end
end
