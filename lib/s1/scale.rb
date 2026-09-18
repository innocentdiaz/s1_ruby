# frozen_string_literal: true

module S1
  # The scale as a value: an immutable set of categories with their definitions,
  # ordered (ordinal — a bare list, rank is order) or not (nominal — label =>
  # description, or a list with `ordered: false`). A category is a point on it:
  # a Level for an ordinal scale, a Symbol for a nominal one, and the scale is
  # the one place a label is spelled — a typo or a rename fails at the reference
  # (KeyError / NoMethodError), never silently:
  #
  #   Severity = S1.scale "cosmetic", "degraded", "blocking"
  #   Severity[:degraded]            # => "degraded", an S1::Level;  Severity[:typo] raises KeyError (fetch is the same)
  #   Severity.fetch("degraded")     # by label, or by its snake-cased key (Severity.keys)
  #   Severity.to_a[1]               # by position; [] is by label only
  #   lvl.blocking?                  # a Level's predicates, one per key of its scale
  #   Team = S1.scale returns: "Refunds, exchanges", billing: "Charges"
  #   Team[:billing]                 # => :billing;  Team.definitions the { label => description }, keyed by label String
  #   Team.definition(:billing)      # => "Charges"; a category off the scale raises KeyError
  #   S1.scale(-> { case_types })    # dynamic: a callable or a Symbol (`source`), `resolve(record)` later
  #
  # A Scale is an instance, and Ruby constants live on modules, so there is no
  # `Severity::BLOCKING`: `Severity[:blocking]` / `Severity.fetch(:blocking)`
  # are the reference spellings, and `lvl.blocking?` on a Level. Two scales
  # with the same labels and kind are equal (a nominal one as a set); a
  # dynamic scale is equal to one with the same source. `name:` and `ordered:`
  # are options: a category so named goes in a positional Hash
  # (`S1.scale({ name: "…", email: "…" })`). Labels are Strings, Symbols or
  # Integers (a Scale, a list or a Hash beside other labels is refused), distinct
  # and non-blank, as are the definitions, which are text; labels and definitions
  # do not mix. A Level of another scale is off this one: `include?` says so
  # and `fetch` raises. A label whose key spells a method the Level already has
  # (`empty`, `frozen`; `present`, `blank` under ActiveSupport) keeps that method's
  # answer — reference it through the scale, or a record's `<field>_<key>?`.
  # Marshal keeps a Scale whole; a YAML round trip reads its categories back as
  # plain Strings.
  class Scale
    include Enumerable

    attr_reader :name, :source, :ordered

    # Snake-cases a label into a key: "Broken, workaround exists" => :broken_workaround_exists.
    def self.key(label) = label.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "").to_sym

    def initialize(*labels, ordered: nil, name: nil, **definitions)
      unless [true, false, nil].include?(ordered)
        raise ArgumentError, "ordered: is true or false (got #{ordered.inspect}); a category named ordered goes in a positional Hash"
      end
      raise ArgumentError, "name: beside keyword definitions is ambiguous; give the definitions as one Hash" if name && definitions.any?

      @name = name
      @ordered = ordered
      first = labels.first if labels.one?
      case first
      when Array        then define(first, definitions, true)
      when Hash         then define([], first, false)
      when Proc, Symbol then @source = first
      else define(labels, definitions, definitions.empty?)
      end
      freeze
    end

    def dynamic? = !@source.nil?
    def ordinal? = resolved! && @ordered
    def nominal? = !ordinal?
    def kind = ordinal? ? "ordinal" : "nominal"
    def labels = resolved! && @labels
    def definitions = resolved! && @definitions
    alias to_h definitions
    def keys = resolved! && @keys
    def each(&) = (resolved! && @categories).each(&)
    def size = labels.size
    # What a question shows per category: its definition, else its label.
    def texts = definitions.map { |label, text| text || label }
    # A category's definition (nil when it has none); off the scale raises KeyError.
    def definition(category) = definitions[fetch(category).to_s]

    # The category at a label (a String, Symbol or Level of this scale), or at its key; off the scale raises KeyError.
    def fetch(label)
      raise KeyError, "#{label.inspect} is on #{label.scale.inspect}, not #{inspect}" if label.is_a?(Level) && !include?(label)

      (at = rank(label)) ? @categories[at] : raise(KeyError, "#{label.inspect} is not on #{name || "the scale"} (#{labels.join(", ")})")
    end
    alias [] fetch

    # A Level belongs by its scale, anything else by its label or key.
    def include?(category) = category.is_a?(Level) ? category.scale == self : !rank(category).nil?
    alias === include?
    alias member? include?

    # A concrete scale from a dynamic one: a Symbol is sent to `context`, a Proc runs on it
    # (instance_exec when it takes no argument, else called with it), or alone without one.
    # A list resolves ordinal and a Hash nominal unless `ordered:` said; a concrete Scale is
    # taken as is when it is of the kind `ordered:` said, and refused otherwise, as a dynamic one is.
    def resolve(context = nil)
      return self unless dynamic?

      value = if @source.is_a?(Symbol) then context.public_send(@source)
              elsif context.nil? then @source.call
              elsif @source.arity.zero? then context.instance_exec(&@source)
              else @source.call(context)
              end
      return Scale.new(value, ordered: @ordered, name: name) if value.is_a?(Array) || value.is_a?(Hash)
      return value if value.is_a?(Scale) && !value.dynamic? && (@ordered.nil? || value.ordered == @ordered)

      raise ValidationError, "#{inspect} resolved to #{value.inspect}; a scale is a list, { label => description }, or an S1::Scale" \
                             "#{" declared ordered: #{@ordered}" if value.is_a?(Scale) && !@ordered.nil?}"
    end

    def ==(other) = other.is_a?(Scale) && identity == other.identity
    alias eql? ==
    def hash = identity.hash

    def inspect = "#<S1::Scale #{"#{name} " if name}#{dynamic? ? "dynamic #{@source.inspect}" : labels.join(separator)}>"
    alias to_s inspect

    protected

    def identity
      return [@source, @ordered] if dynamic?

      [ordinal?, ordinal? ? labels : labels.sort]
    end

    private

    def define(labels, definitions, ordered)
      raise ArgumentError, "give labels or definitions, not both" if labels.any? && definitions.any?

      @labels = distinct!("labels", (labels + definitions.keys).map { |label| label!(label).to_s.freeze }).freeze
      @definitions = defined(definitions).freeze
      @keys = keys_of(@labels)
      @ordered = ordered if @ordered.nil?
      @categories = (@ordered ? levels : @labels.map(&:to_sym)).freeze
      distinct!("definitions", texts)
    end

    def levels = @labels.each_with_index.map { |label, i| Level.new(label, i, self) }
    def keys_of(labels) = labels.group_by { |l| Scale.key(l) }.select { |k, same| same.one? && !k.empty? }.transform_values(&:first).freeze

    def defined(definitions)
      texts = definitions.to_h { |label, text| [label.to_s, definition!(label, text)] }
      @labels.to_h { |label| [label, texts[label]] }
    end

    def label!(label)
      return label if label.is_a?(String) || label.is_a?(Symbol) || label.is_a?(Integer)

      raise ArgumentError, "a label is a String, Symbol or Integer (got #{label.inspect})"
    end

    def definition!(label, text)
      return text && -text if text.nil? || text.is_a?(String)

      raise ValidationError, "a definition is text (got #{text.inspect} for #{label.inspect}); an integer column's indexes are the macro's"
    end

    def distinct!(what, list)
      return list unless list.uniq.size < list.size || list.any?(&:empty?)

      raise ValidationError, "#{what} must be distinct and non-blank (got #{list.inspect})"
    end

    def rank(label) = labels.index(label.to_s) || labels.index(@keys[label.to_s.to_sym])
    def separator = ordinal? ? " < " : " | "

    def resolved! = !dynamic? || raise(ValidationError, "#{inspect} is dynamic; resolve it first")
  end
end
