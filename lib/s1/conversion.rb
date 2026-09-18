# frozen_string_literal: true

module S1
  # ψ prepares: (ψ x) is S1.to_state(x). With `c.psi = true` it is defined on
  # Kernel the way Integer() and Pathname() are. ψ makes evidence *measurable*
  # and measures nothing; judge / choose / score / measure take the measurement
  # (a distribution); the trailing `?` on what follows is the collapse. Between
  # them: arithmetic. Any identifier can stand in (`c.psi = "⍣"`, `c.psi =
  # "State"`). Off by default; the explicit spelling is always S1::State.new.
  #
  #   (ψ"Michael").is? "a man's name"
  #   (ψ chat).measure { |q| q.judge :escalate, "Is the customer asking for a human agent?" }
  module Conversion
    IDENTIFIER = /\A[[:^ascii:]a-zA-Z_][[:^ascii:]\w]*\z/

    class << self
      attr_reader :installed

      # Defines the named function on Kernel; removes the previous one when the
      # name changes or `nil` is given. Idempotent. A name Kernel already has
      # (`p`, `class`, `puts`) is refused rather than overwritten.
      def install!(name)
        name = name&.to_s
        raise ArgumentError, "psi must be a Ruby identifier (got #{name.inspect})" if name && !name.match?(IDENTIFIER)
        return if name == installed
        raise ArgumentError, "`#{name}` is already a Kernel method; pick another name for psi" if name && kernel_method?(name)

        Kernel.send(:remove_method, installed) if installed
        if name
          Kernel.define_method(name) do |evidence = (none = true), **options, &block|
            raise ArgumentError, "#{name} takes no block; use (#{name} x).measure { |q| … }" if block
            next S1.predicates if none # ψ.is "…", ψ.choose "…": a question with no state yet

            S1.to_state(evidence, **options)
          end
          Kernel.send(:private, name)
        end
        @installed = name
      end

      private

      def kernel_method?(name) = Kernel.method_defined?(name) || Kernel.private_method_defined?(name)
    end
  end
end
