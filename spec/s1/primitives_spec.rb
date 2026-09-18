# frozen_string_literal: true

require "open3"

# Primitives extend core classes irreversibly, so each case runs in its own process.
RSpec.describe S1::Primitives do
  def run(script)
    out, err, status = Open3.capture3(RbConfig.ruby, "-I", File.expand_path("../../lib", __dir__), "-e", script)
    raise "#{err}\n#{out}" unless status.success?

    out.strip
  end

  STUB = "S1::Providers::Stub.new(noul: 0.9, choice: :billing, score: 2, e: 0.8)"

  it "is off by default" do
    expect(run('require "s1"; print "x".respond_to?(:noul?)')).to eq("false")
  end

  it "installs via config on String, Hash and Array" do
    script = <<~RUBY
      require "s1"
      S1.configure { |c| c.primitives = true; c.provider = #{STUB} }
      print [
        "text".judge?("q?"),
        { a: 1 }.choose("t?", returns: "R", billing: "B").to_sym,
        [1].score("n?", "few", "some", "many").level,
        { a: 1 }.measure { |q| q.judge :e, "x?" }.true?(:e),
        "text".to_s1(threshold: 0.95).judge?("q?"),
        "text".to_s1.class.name
      ].inspect
    RUBY
    expect(run(script)).to eq('[true, :billing, "many", true, false, "S1::State"]')
  end

  it "mirrors State's names and aliases" do
    script = <<~RUBY
      require "s1"
      S1.configure { |c| c.primitives = true; c.provider = #{STUB} }
      print [
        "text".judge("q?").class.name, "text".noul("q?").to_f, "text".noul?("q?"), "text".ask?("q?"),
        "text".choice("t?", returns: "R", billing: "B"), "text".level("n?", "few", "some", "many").to_i,
        "text".ask { |q| q.judge :e, "x?" }.true?(:e), "text".batch { |q| q.judge :e, "x?" }.true?(:e),
        "text".ask_about { |q| q.judge :e, "x?" }.true?(:e)
      ].inspect
    RUBY
    expect(run(script)).to eq('["S1::Answer::Noul", 0.9, true, true, :billing, 2, true, true, true]')
  end

  it "takes given: on measure, the lens inline, as on every verb" do
    script = <<~RUBY
      require "s1"
      seen = nil
      S1.configure { |c| c.primitives = true; c.provider = S1::Providers::Stub.new { |req| seen = req.state and { e: 0.8 } } }
      "text".measure(given: { policy: "P" }) { |q| q.judge :e, "x?" }
      print seen.inspect
    RUBY
    expect(run(script)).to eq('{:this=>"text", :policy=>"P"}')
  end

  it "defines ψ with c.psi = true, or any identifier given, and removes it when switched" do
    script = <<~RUBY
      require "s1"
      S1.configure { |c| c.psi = true; c.provider = #{STUB} }
      out = [ψ("x").judge?("q?"), ψ("x", threshold: 0.95).judge?("q?")]
      S1.configure { |c| c.psi = "⍣" }
      out << Object.private_method_defined?(:ψ) << ⍣("x").judge?("q?")
      S1.configure { |c| c.psi = false }
      out << Object.private_method_defined?(:⍣)
      out << (begin; S1.configure { |c| c.psi = "not an identifier" }; rescue ArgumentError => e; e.message[/^psi must be a Ruby identifier/]; end)
      print out.inspect
    RUBY
    expect(run(script)).to eq('[true, false, false, true, false, "psi must be a Ruby identifier"]')
  end

  it "still reads c.symbol as c.psi" do
    script = <<~RUBY
      require "s1"
      S1.configure { |c| c.symbol = true; c.provider = #{STUB} }
      print [ψ("x").judge?("q?"), S1.config.psi, S1.config.symbol, S1.config.psi_name, S1.config.symbol_name].inspect
    RUBY
    expect(run(script)).to eq('[true, true, true, "ψ", "ψ"]')
  end

  it "refuses a name for psi Kernel already has, and leaves the current one installed" do
    script = <<~RUBY
      require "s1"
      S1.configure { |c| c.psi = true; c.provider = #{STUB} }
      out = %w[p class puts].map { |name| begin; S1.configure { |c| c.psi = name }; rescue ArgumentError => e; e.message; end }
      out << Object.private_method_defined?(:ψ) << S1::Conversion.installed << ψ("x").judge?("q?")
      print out.inspect
    RUBY
    expect(run(script)).to eq('["`p` is already a Kernel method; pick another name for psi", ' \
                              '"`class` is already a Kernel method; pick another name for psi", ' \
                              '"`puts` is already a Kernel method; pick another name for psi", true, "ψ", true]')
  end

  it "ψ takes no block" do
    script = <<~RUBY
      require "s1"
      S1.configure { |c| c.psi = true; c.provider = #{STUB} }
      print (begin; ψ("x") { }; rescue ArgumentError => e; e.message; end)
    RUBY
    expect(run(script)).to eq("ψ takes no block; use (ψ x).measure { |q| … }")
  end

  it "ψ with no argument is the predicate builder" do
    script = <<~RUBY
      require "s1"
      S1.configure { |c| c.psi = true; c.provider = #{STUB} }
      print [ψ.is?("x").class.name, %w[a b].select(&ψ.is?("x")).size, ψ("a").class.name].inspect
    RUBY
    expect(run(script)).to eq('["S1::Predicate", 2, "S1::State"]')
  end

  it "does not put is? on core classes" do
    expect(run('require "s1"; S1.configure { |c| c.primitives = true }; print "x".respond_to?(:is?)')).to eq("false")
  end

  it "adds ask? as judge?, and yields to a class's own ask?" do
    script = <<~RUBY
      require "s1"
      class Hash; def ask?(*) = :mine; end
      S1.configure { |c| c.primitives = true; c.provider = #{STUB} }
      print ["text".ask?("q?"), { a: 1 }.ask?("q?")].inspect
    RUBY
    expect(run(script)).to eq("[true, :mine]")
  end

  it "installs a subset by name" do
    script = <<~RUBY
      require "s1"
      S1.configure { |c| c.primitives = ["String"] }
      print [String, Hash].map { |k| k.include?(S1::Primitives) }.inspect
    RUBY
    expect(run(script)).to eq("[true, false]")
  end

  it "installs via require" do
    expect(run('require "s1/core_ext"; print S1::Primitives.installed?(Hash)')).to eq("true")
  end

  it "leaves Kernel alone" do
    script = <<~RUBY
      require "s1"
      S1.configure { |c| c.primitives = true }
      print [Object.private_method_defined?(:noul?), S1::Primitives.installed?(Kernel)].inspect
    RUBY
    expect(run(script)).to eq("[false, false]")
  end

  it "refuses Kernel, Object and BasicObject as targets" do
    script = <<~RUBY
      require "s1"
      out = [Kernel, Object, BasicObject, "Object"].map { |t| begin; S1::Primitives.install!([String, t]); rescue ArgumentError => e; e.message; end }
      out << Object.method_defined?(:noul?) << S1::Primitives.installed?(String)
      print out.inspect
    RUBY
    expect(run(script)).to eq('["Kernel is not a primitives target; use a receiver", ' \
                              '"Object is not a primitives target; use a receiver", ' \
                              '"BasicObject is not a primitives target; use a receiver", ' \
                              '"Object is not a primitives target; use a receiver", false, false]')
  end
end
