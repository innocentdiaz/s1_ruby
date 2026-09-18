# frozen_string_literal: true

require "yaml"

RSpec.describe S1::Level do
  let(:scale) { ["Cosmetic", "Broken, workaround exists", "Blocking"] }
  let(:level) { described_class.new("Broken, workaround exists", 1, scale) }
  let(:top) { described_class.new("Blocking", 2, scale) }

  it "is its label, a String, frozen, knowing its position and scale" do
    expect(level).to be_a(String)
    expect(level).to eq("Broken, workaround exists")
    expect(level).to be_frozen
    expect(level.position).to eq(1)
    expect(level.to_i).to eq(1)
    expect(level.scale).to eq(S1.scale(*scale))
    expect(level.scale).to be_a(S1::Scale).and be_frozen
    expect(level.labels).to eq(scale)
    expect(level.labels).to be_frozen
    expect("#{level}!").to eq("Broken, workaround exists!")
  end

  it "gives the scale as an S1::Scale whose points are Levels that compare by rank, as Answer::Score#scale does" do
    expect(level.scale.to_a).to all(be_a(described_class))
    expect(level.scale.map(&:position)).to eq([0, 1, 2])
    expect(level.scale.to_a.last >= "Broken, workaround exists").to be(true)
    expect(level.scale.max).to eq("Blocking")
    expect(level.scale.include?(level)).to be(true)
    lo, mid, hi = described_class.new("mid", 1, %w[low mid high]).scale.to_a
    expect(hi >= "mid").to be(true)
    expect([hi, lo, mid].sort).to eq(%w[low mid high])
    expect(lo < mid).to be(true)
  end

  it "builds an ordinal Scale from an Array of labels, or takes the Scale itself" do
    severity = S1.scale(*scale)
    expect(described_class.new("Blocking", 2, severity).scale).to be(severity)
    expect(described_class.new("Blocking", 2, scale).scale).to eq(severity)
    expect(severity[:blocking]).to be_a(described_class)
    expect(severity[:blocking].scale).to be(severity)
    expect(severity.to_a.map(&:scale)).to all(be(severity))
  end

  it "compares only on its own scale: across scales <=> raises" do
    other = S1.scale("Cosmetic", "Broken, workaround exists", "Blocking", "Outage")
    stranger = described_class.new("Blocking", 2, other)
    expect { level <=> stranger }.to raise_error(ArgumentError, "different scales: #{level.scale.inspect} vs #{other.inspect}")
    expect { level < stranger }.to raise_error(ArgumentError, /different scales/)
    expect { [level, stranger].sort }.to raise_error(ArgumentError, /different scales/)
    expect(level <=> described_class.new("Blocking", 2, S1.scale(*scale))).to eq(-1)
    expect(level == stranger).to be(false)
    expect(top == stranger).to be(true)
    expect(other.include?(top)).to be(false)
    expect(level.scale.include?(stranger)).to be(false)
  end

  it "answers a predicate per label of its scale, by the label's key, and responds to them" do
    expect(level.broken_workaround_exists?).to be(true)
    expect(level.blocking?).to be(false)
    expect(level.cosmetic?).to be(false)
    expect(top.blocking?).to be(true)
    expect(level).to respond_to(:blocking?)
    expect(level).to respond_to(:broken_workaround_exists?)
    expect(level).not_to respond_to(:severe?)
    expect(level).not_to respond_to(:blocking)
    expect { level.severe? }.to raise_error(NoMethodError)
    expect { level.blocking?(1) }.to raise_error(ArgumentError)
    expect(level.empty?).to be(false)
    expect(described_class.new("mid", 1, %w[low mid high]).mid?).to be(true)
  end

  it "keeps String#index: position is the scale position, index finds a substring" do
    expect(level.index("k")).to eq(3)
    expect(level.index("zzz")).to be_nil
    expect { level.index }.to raise_error(ArgumentError)
  end

  it "compares by position against a Level, a Numeric or a label on the scale" do
    expect(level <=> top).to eq(-1)
    expect(level < top).to be(true)
    expect(level <=> 1).to eq(0)
    expect(level >= 1).to be(true)
    expect(level > 1).to be(false)
    expect(level <=> 1.5).to eq(-1)
    expect(level < 1.5).to be(true)
    expect(level > 0.5).to be(true)
    expect(level.clamp(0.0, 0.5)).to eq(0.5)
    expect(level <=> "Blocking").to eq(-1)
    expect(level >= "Cosmetic").to be(true)
    expect(level >= "Blocking").to be(false)
    expect(level.between?("Cosmetic", "Blocking")).to be(true)
  end

  it "is incomparable with a label off the scale or anything else" do
    expect(level <=> "Severe").to be_nil
    expect { level >= "Severe" }.to raise_error(ArgumentError)
    expect(level <=> :mid).to be_nil
    expect(level <=> nil).to be_nil
  end

  it "dumps to YAML as the plain label, so it loads back as a String and passes safe_load" do
    lvl = described_class.new("mid", 1, %w[low mid high])
    expect(YAML.dump(lvl)).to eq("--- mid\n")
    expect(YAML.load(YAML.dump(lvl))).to eq("mid")
    expect(YAML.load(YAML.dump(lvl))).to be_an_instance_of(String)
    expect(YAML.safe_load(YAML.dump(lvl))).to eq("mid")
    expect(YAML.safe_load(YAML.dump(severity: lvl), permitted_classes: [Symbol])).to eq(severity: "mid")
    expect(YAML.load(YAML.dump(described_class.new("yes", 1, %w[no yes])))).to eq("yes")
  end

  it "equals its index and its label" do
    expect(level == 1).to be(true)
    expect(level == 2).to be(false)
    expect(level).to eq(1.0)
    expect(level).not_to eq(1.5)
    expect(level.between?(1.0, 1.0)).to be(true)
    expect(level == "Broken, workaround exists").to be(true)
    expect(level == "Blocking").to be(false)
    expect(1 == level).to be(true) # rubocop:disable Style/YodaCondition
    expect("Broken, workaround exists" == level).to be(true) # rubocop:disable Style/YodaCondition
  end

  it "coerces, so an Integer on the left and integer ranges work" do
    expect(2 <= level).to be(false) # rubocop:disable Style/YodaCondition
    expect(1 <= level).to be(true) # rubocop:disable Style/YodaCondition
    expect((1..) === level).to be(true) # rubocop:disable Style/CaseEquality
    expect((3..) === level).to be(false) # rubocop:disable Style/CaseEquality
    expect((0..1) === level).to be(true) # rubocop:disable Style/CaseEquality
    expect((2..3) === level).to be(false) # rubocop:disable Style/CaseEquality
    expect(level.coerce(2)).to eq([2, 1])
  end

  it "is a Hash key interchangeable with its label" do
    h = { level => :found }
    expect(h["Broken, workaround exists"]).to eq(:found)
    expect({ "Broken, workaround exists" => :found }[level]).to eq(:found)
    expect(level.hash).to eq("Broken, workaround exists".hash)
    expect(level).to eql("Broken, workaround exists")
  end

  it "sorts by position, not alphabet" do
    labels = %w[low mid high]
    levels = labels.each_with_index.map { |text, i| described_class.new(text, i, labels) }
    expect(levels.shuffle.sort).to eq(%w[low mid high])
    expect(levels.max).to eq("high")
    expect(labels.sort).to eq(%w[high low mid])
  end
end
