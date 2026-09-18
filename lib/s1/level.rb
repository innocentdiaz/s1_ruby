# frozen_string_literal: true

module S1
  # What a score collapses to: the level's label, a String that knows its
  # position and its scale (an S1::Scale). Being a String it interpolates,
  # stores and serializes as the label; knowing its position it compares by
  # that and not by alphabet:
  #
  #   lvl = (ψ text).level "How severe?", "Cosmetic", "Degraded", "Blocking"   # => "Blocking"
  #   lvl >= 1               lvl >= "Degraded"          lvl.to_i   # => 2
  #   lvl.blocking?          lvl.scale                  # => #<S1::Scale Cosmetic < Degraded < Blocking>
  #   case r in { severity: 2.. }   /   in { severity: ^(lvl.scale.fetch(:blocking)) }
  #   tickets.sort_by(&ψ.score(…))  # by expected position;  group_by(&ψ.level(…)) keys are the labels
  #
  # Every key of the scale is a predicate on the level (`lvl.blocking?`, by
  # the label's key — Scale#keys) unless the level already answers it (`empty?`
  # is String's, `present?` ActiveSupport's). Two levels compare only on the
  # same scale; across scales `<=>` raises, while `==` is the label's, or the
  # position's against a Numeric. Keep the level on the left of a comparison
  # with a label (`"Degraded" <= lvl` is String's own compare). Integer ranges
  # match (`when 2..`); a bare Integer `when 2` never does — Ruby's literal
  # case dispatch skips it — so compare positions with a range, or through the
  # scale (`when Severity[:blocking]`). Ranges of labels do not match. Every
  # String method is still String's: `lvl.index("i")` finds a substring.
  class Level < String
    attr_reader :position, :scale

    # `scale` is an S1::Scale, or the labels (an Array) of an ordinal one; `text` is its label at `position`.
    def initialize(text, position, scale)
      super(text)
      @position = position
      @scale = scale.is_a?(Scale) ? scale : Scale.new(scale)
      raise ArgumentError, "#{text.inspect} is not at #{position} on #{@scale.inspect}" unless @scale.labels[position] == text

      freeze
    end

    def to_i = position
    def labels = scale.labels

    # By position: against a Level on the same scale or a Numeric directly, against a label on
    # the scale by that label's position; a label off it, or anything else, is incomparable (nil).
    def <=>(other)
      case other
      when Level   then same_scale!(other) && position <=> other.position
      when Numeric then position <=> other
      when String  then labels.index(other)&.then { |at| position <=> at }
      end
    end

    def ==(other) = other.is_a?(Numeric) ? position == other : super

    def coerce(number) = [number, position]

    # YAML sees the label alone, quoted as Psych quotes any String.
    def encode_with(coder) = coder.represent_object(nil, to_str)

    def respond_to_missing?(name, include_private = false) = predicate(name) ? true : super

    private

    def method_missing(name, *args, &)
      label = predicate(name) or return super
      raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0)" if args.any?

      self == label
    end

    def predicate(name) = name.end_with?("?") ? scale.keys[name.to_s.delete_suffix("?").to_sym] : nil

    def same_scale!(other)
      scale == other.scale || raise(ArgumentError, "different scales: #{scale.inspect} vs #{other.scale.inspect}")
    end
  end
end
