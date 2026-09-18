# frozen_string_literal: true

module S1
  # Opt-in core extension: the evidence itself becomes the receiver — each verb
  # prepares it (to_s1) and measures. (The gem's operations are judge / choose /
  # score / measure; "primitives" here names only this extension of Ruby's core
  # classes.)
  #
  #   S1.configure { |c| c.primitives = true }              # String, Hash, Array
  #   S1.configure { |c| c.primitives = [String] }          # or a subset
  #   require "s1/core_ext"                                 # or the require-style opt-in
  #
  #   "Can I talk to a real person?".judge?("Is the customer asking for a human agent?")
  #   { ticket: text }.choose("Which team?", returns: "Refunds", billing: "Charges")   # => Answer::Choice
  #   { ticket: text }.choice("Which team?", returns: "Refunds", billing: "Charges")   # => :returns
  #   { ticket: text }.measure { |q| q.judge :escalate, "..." }
  #
  # Each method delegates to S1::State.new(self); #to_s1 gives you the State
  # when you need per-call options. The names and aliases mirror State — a verb
  # measures and returns the distribution, a noun returns the thing it names, a
  # `?` returns a boolean: judge (noul), judge? (noul?, ask?), choose, choice,
  # score, level, measure (ask, batch, ask_about). A class's own method of one
  # of those names always wins, since the module is included below it.
  # is? / same_as? / given stay on State — reach them through #to_s1 or ψ.
  module Primitives
    TARGETS = [String, Hash, Array].freeze
    # Including here would put the verbs on everything, receiver or not.
    UNIVERSAL = [Kernel, Object, BasicObject].freeze

    def to_s1(**) = State.new(self, **)
    def judge(instructions, **kw) = to_s1.judge(instructions, **kw)
    alias noul judge
    def judge?(instructions, **kw) = to_s1.judge?(instructions, **kw)
    alias noul? judge?
    alias ask? judge?
    def choose(instructions, **kw) = to_s1.choose(instructions, **kw)
    def choice(instructions, **kw) = to_s1.choice(instructions, **kw)
    def score(instructions, *levels, **kw) = to_s1.score(instructions, *levels, **kw)
    def level(instructions, *levels, **kw) = to_s1.level(instructions, *levels, **kw)
    def measure(questions = nil, **kw, &) = to_s1.measure(questions, **kw, &)
    alias ask measure
    alias batch measure
    alias ask_about measure

    class << self
      # Idempotent. `true` installs on all TARGETS; an array narrows or extends
      # it (classes, or their names). Returns the modules extended.
      def install!(targets = true)
        modules = if targets == true
                    TARGETS
                  else
                    Array(targets).map do |t|
                      t.is_a?(Module) ? t : Object.const_get(t.to_s)
                    end
                  end
        universal = modules.find { |m| UNIVERSAL.include?(m) }
        raise ArgumentError, "#{universal} is not a primitives target; use a receiver" if universal

        modules.each { |mod| mod.include(self) unless mod.include?(self) }
        modules
      end

      def installed?(mod) = mod.include?(self)
    end
  end
end
