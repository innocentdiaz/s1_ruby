# frozen_string_literal: true

RSpec.describe S1::Scale do
  let(:severity) { S1.scale("cosmetic", "degraded", "blocking") }
  let(:team) { S1.scale(returns: "Refunds, exchanges", billing: "Charges") }

  describe "construction" do
    it "is ordinal from a bare list (order is rank), with Symbols stringified; S1.scale is Scale.new" do
      expect(severity).to be_ordinal
      expect(severity).not_to be_nominal
      expect(severity.kind).to eq("ordinal")
      expect(severity.ordered).to be(true)
      expect(severity.labels).to eq(%w[cosmetic degraded blocking])
      expect(severity.size).to eq(3)
      expect(S1.scale(:low, :high).labels).to eq(%w[low high])
      expect(described_class.new(%w[low high])).to eq(S1.scale("low", "high"))
      expect(described_class.new("low", "high")).to be_a(described_class)
      expect(described_class).not_to respond_to(:[])
    end

    it "refuses duplicate or blank labels, and duplicate or blank definitions" do
      expect { S1.scale("a", "a", "b") }.to raise_error(S1::ValidationError, 'labels must be distinct and non-blank (got ["a", "a", "b"])')
      expect { S1.scale("a", "") }.to raise_error(S1::ValidationError, /distinct and non-blank/)
      expect { S1.scale(a: "A", "a" => "B") }.to raise_error(S1::ValidationError, /distinct and non-blank/)
      expect { S1.scale({ a: "same", b: "same" }, ordered: true) }
        .to raise_error(S1::ValidationError, 'definitions must be distinct and non-blank (got ["same", "same"])')
      expect { S1.scale(a: "b", b: nil) }.to raise_error(S1::ValidationError, /definitions must be distinct/)
      expect { S1.scale(a: "", b: "B") }.to raise_error(S1::ValidationError, /definitions must be distinct and non-blank/)
    end

    it "keeps a label whose key spells a method the Level already has: the Level answers that method, the scale still resolves it" do
      fullness = S1.scale("empty", "partial", "full")
      expect(fullness.keys).to eq(empty: "empty", partial: "partial", full: "full")
      expect(fullness[:empty].empty?).to be(false)
      expect(fullness[:partial].partial?).to be(true)
      expect(S1.scale("thawed", "frozen")[:frozen].frozen?).to be(true)
      expect(S1.scale(empty: "nothing", full: "everything")).to be_nominal
      expect(S1::Answer::Score.new(id: :s, legend: { 0 => "nil", 1 => "some" }, probabilities: { "1" => 1.0 },
                                   confidence: 1.0).level).to eq("some")
    end

    it "refuses a label that is not a String, Symbol or Integer (a Scale, a list, a Hash), and labels beside definitions" do
      expect do
        S1.scale(severity)
      end.to raise_error(ArgumentError,
                         "a label is a String, Symbol or Integer (got #<S1::Scale cosmetic < degraded < blocking>)")
      expect { S1.scale(severity, "x") }.to raise_error(ArgumentError, /a label is a String/)
      expect { S1.scale("a", %w[b c]) }.to raise_error(ArgumentError, 'a label is a String, Symbol or Integer (got ["b", "c"])')
      expect { S1.scale("a", { b: "d" }) }.to raise_error(ArgumentError, /a label is a String/)
      expect { S1.scale("a", nil) }.to raise_error(ArgumentError, /got nil/)
      expect { S1.scale("a", b: "desc") }.to raise_error(ArgumentError, "give labels or definitions, not both")
      expect { S1.scale(%w[a], b: "desc") }.to raise_error(ArgumentError, "give labels or definitions, not both")
    end

    it "takes text as a definition, frozen — an integer is the macro's index, not a definition" do
      expect { S1.scale({ "can wait" => 10, "today" => 20 }, ordered: true) }
        .to raise_error(S1::ValidationError, 'a definition is text (got 10 for "can wait"); an integer column\'s indexes are the macro\'s')
      expect { S1.scale(a: { is: "x" }) }.to raise_error(S1::ValidationError, /a definition is text/)
      loose = +"Refunds"
      t = S1.scale(returns: loose, billing: "Charges")
      expect(t.definitions["returns"]).to be_frozen
      expect { t.definitions["returns"] << "!" }.to raise_error(FrozenError)
      expect(loose).not_to be_frozen
      expect(t.texts).to eq(%w[Refunds Charges])
    end

    it "gives a category's definition by definition(category), nil when it has none; off the scale raises" do
      expect(team.definition(:billing)).to eq("Charges")
      expect(team.definition("returns")).to eq("Refunds, exchanges")
      expect(team.definitions[team[:billing]]).to be_nil
      expect(severity.definition(severity[:degraded])).to be_nil
      expect { team.definition(:typo) }.to raise_error(KeyError, ":typo is not on the scale (returns, billing)")
    end

    it "refuses name: beside keyword definitions, and ordered: that is not true / false — a category so named goes in a positional Hash" do
      expect { S1.scale(name: "Full name", email: "Email") }
        .to raise_error(ArgumentError, "name: beside keyword definitions is ambiguous; give the definitions as one Hash")
      expect { S1.scale(ordered: "First come", random: "Any") }
        .to raise_error(ArgumentError, /ordered: is true or false \(got "First come"\); a category named ordered goes in a positional Hash/)
      expect(S1.scale({ name: "Full name", email: "Email" }).labels).to eq(%w[name email])
      expect(S1.scale({ name: "Full name", email: "Email" }, name: "Field").name).to eq("Field")
      expect(S1.scale({ ordered: "First come", random: "Any" }).fetch(:ordered)).to be(:ordered)
      expect(S1.scale("a", "b", name: "AB").name).to eq("AB")
      expect(S1.scale("a", "b", ordered: false).ordered).to be(false)
    end

    it "is nominal from label => description (nil allowed), or a list with ordered: false" do
      expect(team).to be_nominal
      expect(team.kind).to eq("nominal")
      expect(team.labels).to eq(%w[returns billing])
      expect(team.definitions).to eq("returns" => "Refunds, exchanges", "billing" => "Charges")
      expect(team.to_h).to eq(team.definitions)
      loose = S1.scale("a", "b", ordered: false)
      expect(loose).to be_nominal
      expect(loose.definitions).to eq("a" => nil, "b" => nil)
      expect(S1.scale(a: nil, b: "B").definitions).to eq("a" => nil, "b" => "B")
      expect(described_class.new({ "a" => "A", "b" => "B" })).to eq(S1.scale(a: "A", b: "B"))
      expect(S1.scale({ a: "A", b: "B" }, ordered: true)).to be_ordinal
      expect(severity.definitions).to eq("cosmetic" => nil, "degraded" => nil, "blocking" => nil)
    end

    it "is immutable: frozen, labels frozen Strings, definitions frozen" do
      expect(severity).to be_frozen
      expect(severity.labels).to be_frozen
      expect(severity.labels).to all(be_frozen)
      expect(severity.labels).to all(be_an_instance_of(String))
      expect(severity.definitions).to be_frozen
      expect(team.definitions).to be_frozen
      expect { severity.labels << "x" }.to raise_error(FrozenError)
    end

    it "takes a name: for messages" do
      named = S1.scale("lo", "hi", name: "Grade")
      expect(named.name).to eq("Grade")
      expect(severity.name).to be_nil
      expect(named.inspect).to eq("#<S1::Scale Grade lo < hi>")
      expect { named.fetch(:mid) }.to raise_error(KeyError, ":mid is not on Grade (lo, hi)")
    end
  end

  describe "categories" do
    it "enumerates Levels on an ordinal scale and Symbols on a nominal one" do
      expect(severity.to_a).to all(be_a(S1::Level))
      expect(severity.to_a).to eq(%w[cosmetic degraded blocking])
      expect(severity.map(&:position)).to eq([0, 1, 2])
      expect(severity.to_a.map(&:scale)).to all(be(severity))
      expect(severity.max).to eq("blocking")
      expect(severity.first).to eq("cosmetic")
      expect(team.to_a).to eq(%i[returns billing])
      expect(team.each_with_index.to_a).to eq([[:returns, 0], [:billing, 1]])
      expect(described_class.ancestors).to include(Enumerable)
    end

    it "[] gives the category at a label, a Symbol, a Level or a snake-cased key; off the scale it raises, as fetch does" do
      expect(severity["degraded"]).to be_a(S1::Level)
      expect(severity["degraded"].position).to eq(1)
      expect(severity[:degraded]).to eq("degraded")
      expect(severity[severity[:degraded]]).to eq("degraded")
      expect { severity[:severe] }.to raise_error(KeyError, ":severe is not on the scale (cosmetic, degraded, blocking)")
      expect { severity["Degraded"] }.to raise_error(KeyError)
      expect { severity[1] }.to raise_error(KeyError, "1 is not on the scale (cosmetic, degraded, blocking)")
      expect(severity.to_a[1]).to eq("degraded")
      expect(team[:billing]).to be(:billing)
      expect(team["billing"]).to be(:billing)
      expect { team[:legal] }.to raise_error(KeyError)
      expect(S1.scale(1, 2, 3)[1]).to eq("1")
      expect(S1.scale(1, 2, 3)[1].position).to eq(0)
      prose = S1.scale("Cosmetic", "Broken, workaround exists", "Blocking issue")
      expect(prose[:broken_workaround_exists]).to eq("Broken, workaround exists")
      expect(prose[:blocking_issue].position).to eq(2)
      expect(prose.keys)
        .to eq(cosmetic: "Cosmetic", broken_workaround_exists: "Broken, workaround exists", blocking_issue: "Blocking issue")
      expect(prose.keys).to be_frozen
    end

    it "leaves colliding keys out, so neither label is reachable by key and a fetch is loud; a label with no key has none" do
      grades = S1.scale("A+", "A", "A-", "B")
      expect(grades.keys).to eq(b: "B")
      expect { grades[:a] }.to raise_error(KeyError)
      expect(grades["A+"]).to eq("A+")
      expect { grades.fetch(:a) }.to raise_error(KeyError)
      expect(grades["A"].respond_to?(:a?)).to be(false)
      fire = S1.scale("🔥", "ok")
      expect(fire.keys).to eq(ok: "ok")
      expect { fire.fetch("") }.to raise_error(KeyError, '"" is not on the scale (🔥, ok)')
      expect { fire.fetch(nil) }.to raise_error(KeyError)
      expect { S1.scale("a", "-").fetch(nil) }.to raise_error(KeyError)
      expect(fire["🔥"].position).to eq(0)
    end

    it "fetch raises a KeyError naming the label and the scale" do
      expect(severity.fetch(:blocking)).to eq("blocking")
      expect(severity.fetch("blocking")).to be_a(S1::Level)
      expect(team.fetch(:returns)).to be(:returns)
      expect { severity.fetch("severe") }.to raise_error(KeyError, "\"severe\" is not on the scale (cosmetic, degraded, blocking)")
      expect { severity.fetch(:severe) }.to raise_error(KeyError, ":severe is not on the scale (cosmetic, degraded, blocking)")
      expect { team.fetch(:legal) }.to raise_error(KeyError, ":legal is not on the scale (returns, billing)")
    end

    it "include?, member? and === take a label, a Symbol, or a Level of this very scale; fetch of another scale's Level raises" do
      expect(severity).to include("degraded")
      expect(severity).to include(:degraded)
      expect(severity).to include(severity[:degraded])
      expect(severity).not_to include("severe")
      expect(severity.include?(1)).to be(false)
      foreign = S1::Level.new("degraded", 1, %w[cosmetic degraded blocking severe])
      expect(severity.include?(foreign)).to be(false)
      expect(severity.member?(foreign)).to be(false)
      expect(severity.member?(severity[:degraded])).to be(true)
      expect { severity.fetch(foreign) }
        .to raise_error(KeyError, '"degraded" is on #<S1::Scale cosmetic < degraded < blocking < severe>, ' \
                                  "not #<S1::Scale cosmetic < degraded < blocking>")
      expect { severity[S1.scale("degraded", "x")[:degraded]] }.to raise_error(KeyError, /is on #<S1::Scale degraded < x>, not/)
      expect(severity.fetch(S1::Level.new("degraded", 1, %w[cosmetic degraded blocking]))).to be(severity[:degraded])
      expect(severity.include?(S1::Level.new("degraded", 1, %w[cosmetic degraded blocking]))).to be(true)
      expect { S1::Level.new("nope", 7, severity) }
        .to raise_error(ArgumentError, '"nope" is not at 7 on #<S1::Scale cosmetic < degraded < blocking>')
      expect { S1::Level.new("degraded", 0, severity) }.to raise_error(ArgumentError, /"degraded" is not at 0/)
      expect(team).to include(:billing)
      expect(team).not_to include(:legal)
      expect(severity === "blocking").to be(true) # rubocop:disable Style/CaseEquality
      route = case severity[:blocking]
              when team then :team
              when severity then :severity
              end
      expect(route).to eq(:severity)
      expect(%w[blocking severe].grep(severity)).to eq(%w[blocking])
    end
  end

  describe "equality" do
    it "is by labels and kind: order counts on an ordinal scale, not on a nominal one; names and definitions do not" do
      expect(severity).to eq(S1.scale("cosmetic", "degraded", "blocking"))
      expect(severity).to eq(S1.scale({ cosmetic: "no impact", degraded: "a workaround", blocking: "none" }, ordered: true))
      described = S1.scale({ cosmetic: "no impact", degraded: "a workaround", blocking: "none" }, ordered: true)
      expect(described.texts).to eq(["no impact", "a workaround", "none"])
      expect(severity.texts).to eq(severity.labels)
      expect(severity).to eql(S1.scale(:cosmetic, :degraded, :blocking))
      expect(severity.hash).to eq(S1.scale("cosmetic", "degraded", "blocking").hash)
      expect(severity).to eq(S1.scale("cosmetic", "degraded", "blocking", name: "Severity"))
      expect(severity).not_to eq(S1.scale("blocking", "degraded", "cosmetic"))
      expect(severity).not_to eq(S1.scale("cosmetic", "degraded", "blocking", ordered: false))
      expect(severity).not_to eq(%w[cosmetic degraded blocking])
      expect(team).to eq(S1.scale(billing: nil, returns: nil))
      expect(team.hash).to eq(S1.scale(billing: nil, returns: nil).hash)
      expect(team).not_to eq(S1.scale(returns: nil, billing: nil, legal: nil))
      expect({ severity => 1 }[S1.scale("cosmetic", "degraded", "blocking")]).to eq(1)
      expect([severity, S1.scale("cosmetic", "degraded", "blocking")].uniq.size).to eq(1)
    end
  end

  describe "#inspect" do
    it "shows the labels with < on an ordinal scale and | on a nominal one" do
      expect(severity.inspect).to eq("#<S1::Scale cosmetic < degraded < blocking>")
      expect(team.inspect).to eq("#<S1::Scale returns | billing>")
      expect(severity.to_s).to eq(severity.inspect)
    end
  end

  describe "a dynamic scale" do
    let(:record) { Struct.new(:case_types).new(%w[mva premises]) }

    it "stores a callable or a Symbol, and resolves on a context to a concrete scale" do
      by_method = S1.scale(:case_types)
      expect(by_method).to be_dynamic
      expect(by_method.source).to eq(:case_types)
      expect(severity.source).to be_nil
      expect(by_method.resolve(record)).to eq(S1.scale("mva", "premises"))
      expect(by_method.resolve(record)).not_to be_dynamic
      expect(S1.scale(:case_types, ordered: false).resolve(record)).to be_nominal
      expect(S1.scale(:case_types).ordered).to be_nil
      expect(S1.scale(:case_types, ordered: false).ordered).to be(false)
      expect(S1.scale(:case_types, name: "Kind").resolve(record).name).to eq("Kind")
      by_block = S1.scale(-> { case_types })
      expect(by_block.resolve(record)).to eq(S1.scale("mva", "premises"))
      by_arg = S1.scale(->(r) { r.case_types.to_h { |c| [c, c.upcase] } })
      expect(by_arg.resolve(record)).to eq(S1.scale(mva: "MVA", premises: "PREMISES"))
      expect(by_arg.resolve(record).definitions["mva"]).to eq("MVA")
      alone = S1.scale(-> { %w[a b] })
      expect(alone.resolve).to eq(S1.scale("a", "b"))
      ready = S1.scale("x", "y")
      expect(S1.scale(-> { ready }).resolve).to be(ready)
      expect(severity.resolve(record)).to be(severity)
      expect(severity).not_to be_dynamic
    end

    it "refuses a source that resolves to anything but a list, a Hash or a Scale, or to a Scale of the other kind than ordered: said" do
      expect { S1.scale(-> {}).resolve }.to raise_error(S1::ValidationError, /resolved to nil/)
      expect { S1.scale(:case_types).resolve(Struct.new(:case_types).new(nil)) }
        .to raise_error(S1::ValidationError, /dynamic :case_types> resolved to nil; a scale is a list, \{ label => description \}, or an S1::Scale\z/)
      expect { S1.scale(:case_types).resolve(Struct.new(:case_types).new("mva, slip")) }
        .to raise_error(S1::ValidationError, /resolved to "mva, slip"/)
      expect { S1.scale(:case_types).resolve(Struct.new(:case_types).new(["mva", nil])) }
        .to raise_error(ArgumentError, /a label is a String, Symbol or Integer \(got nil\)/)
      expect { S1.scale(:case_types, ordered: false).resolve(Struct.new(:case_types).new(severity)) }
        .to raise_error(S1::ValidationError, /resolved to #<S1::Scale cosmetic < degraded < blocking>; .* declared ordered: false\z/)
      expect(S1.scale(:case_types, ordered: true).resolve(Struct.new(:case_types).new(severity))).to be(severity)
      expect(S1.scale(:case_types).resolve(Struct.new(:case_types).new(team))).to be(team)
      expect { S1.scale(-> { S1.scale(:other) }).resolve }
        .to raise_error(S1::ValidationError,
                        /\A#<S1::Scale dynamic #<Proc.*> resolved to #<S1::Scale dynamic :other>; a scale is a list, .*S1::Scale\z/)
      expect(S1.scale(-> { {} }).resolve).to be_nominal
      expect(S1.scale(-> { [] }).resolve).to be_ordinal
      expect(S1.scale({})).to be_nominal
    end

    it "raises on every other reading until resolved, is equal by source, and inspects as dynamic" do
      dynamic = S1.scale(:case_types)
      %i[labels definitions keys to_a size ordinal? nominal? kind].each do |reader|
        expect { dynamic.public_send(reader) }
          .to raise_error(S1::ValidationError, "#<S1::Scale dynamic :case_types> is dynamic; resolve it first"), reader.to_s
      end
      expect { dynamic[:mva] }.to raise_error(S1::ValidationError, /resolve it first/)
      expect { dynamic.include?(:mva) }.to raise_error(S1::ValidationError, /resolve it first/)
      expect(dynamic.inspect).to eq("#<S1::Scale dynamic :case_types>")
      expect(dynamic).to eq(S1.scale(:case_types))
      expect(dynamic.hash).to eq(S1.scale(:case_types).hash)
      expect(dynamic).not_to eq(S1.scale(:other))
      expect(dynamic).not_to eq(S1.scale(:case_types, ordered: false))
      expect(dynamic).to be_frozen
      expect(dynamic.name).to be_nil
    end
  end
end
