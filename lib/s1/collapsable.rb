# frozen_string_literal: true

module S1
  # `Collapsable` is the interface — has `collapse`. A `Distribution` is one
  # question's measurement (id, probabilities, confidence, scale); a `Result` is
  # a batch of them, collapsable elementwise.
  #
  # One contract, `collapse(threshold)` — the threshold only matters to a noul
  # (which carries its own); the others take and ignore it, so a Result
  # collapses every distribution through one call. Each kind names its collapse
  # and exposes Ruby's own conversions:
  #
  #   kind             collapse →                its own name   Ruby idioms
  #   Answer::Noul     true / false               true?          !  !!  to_f  Comparable  & | ~
  #   Answer::Choice   a Symbol                   choice         to_sym  to_s  ==
  #   Answer::Score    an S1::Level               level          key  to_f  levels
  #   Result           { id => collapsed value }  to_h           deconstruct_keys (case … in)
  #
  # A `?` method returns a boolean, as in Ruby, so `?` exists only for a noul.
  # On a State the nouns choice and level are verb + collapse in one call, and
  # the identity holds everywhere: x.choice(args) == x.choose(args).collapse,
  # x.level(args) == x.score(args).collapse. The noun noul names the dichotomous
  # distribution itself: x.noul(args) == x.judge(args).
  #
  # The distribution is the information; `collapse` is the lossy summary — take it last.
  module Collapsable
    def collapse(*)
      raise NotImplementedError, "#{self.class}#collapse"
    end
  end
end
