# frozen_string_literal: true

require "json"
require "open3"

module S1
  module Providers
    # cua-s1-forms (huggingface.co/cua-ai/cua-s1-forms): a small jev-like
    # one-pass option scorer — context in, one probability per option out.
    # Choice only, local, byte-limited. A different creature from jev in every
    # way but the shape of the answer, which is the point of having it.
    #
    # Transport: a Python sidecar (support/cua_s1_sidecar.py) holding the
    # checkpoint, one JSON line per question. Needs `cua-s1` and torch on the
    # Python side; the checkpoint as safetensors + json.
    #
    #   S1.configure { |c| c.provider = :cua; c.cua.checkpoint = "cua-s1-forms" }
    #
    # Translation this provider owns: the context string is in the checkpoint's
    # own shape — `TASK <text>` then the state (as given, or JSON) on the next
    # line, the delimiter cua-s1's render_context uses (a label, a space, the
    # text; segments joined by "\n"; no colon) — with the question's instructions
    # (a String, or a Hash as JSON) as the task: the model has no other slot for
    # the concept. A state that already opens with a TASK line keeps that one,
    # the instructions spliced into it after "; ", so the model never sees two.
    # Choice categories become option strings — the key, or "key: description"
    # when a description is given; the whole context is held to the model's
    # byte limit; the winner is the argmax and confidence is its probability.
    # noul and score are refused (UnsupportedError) rather than emulated: the
    # model is trained on form elements, not propositions.
    class Cua < Base
      SIDECAR = File.expand_path("../../../support/cua_s1_sidecar.py", __dir__)
      MODEL = "cua-s1-forms"

      settings :cua, checkpoint: nil, python: "python3", device: "auto"

      attr_reader :config

      def initialize(checkpoint: nil, python: nil, script: SIDECAR, device: nil)
        super()
        section = S1.config.cua
        @checkpoint = checkpoint || section.checkpoint
        @command = [python || section.python, script, @checkpoint, device || section.device]
      end

      def supports?(question) = question.is_a?(Question::Choice)
      def model = @checkpoint || MODEL

      def call(request)
        boot unless @stdin # the byte limits come from the checkpoint's config
        distributions = request.questions.to_h do |id, question|
          options = question.criteria.map { |key, desc| desc ? "#{key}: #{desc}" : key.to_s }
          probs = score(context_for(question.instructions, request.state), options)
          probabilities = question.categories.zip(probs).to_h
          pick, confidence = probabilities.max_by { |_, p| p }
          [id, distribution(id, question, raw: probs, choice: pick, probabilities: probabilities, confidence: confidence)]
        end
        build_result(distributions: distributions, model: MODEL, usage: { input_tokens: 0, output_tokens: 0 })
      end

      def close
        @stdin&.close
        @wait&.value
        @stdin = @stdout = @wait = nil
      end

      private

      def context_for(instructions, state)
        text = task_line(as_text(instructions), as_text(state))
        limit = config&.dig("context_tokens")
        raise ValidationError, "cua-s1 context is limited to #{limit} bytes (got #{text.bytesize})" if limit && text.bytesize > limit

        text
      end

      def task_line(task, state)
        return "TASK #{task}\n#{state}" unless state.start_with?("TASK ")

        opening, rest = state.split("\n", 2)
        ["#{opening}; #{task}", rest].compact.join("\n")
      end

      def as_text(value) = value.is_a?(String) ? value : JSON.generate(value)

      def score(context, options)
        @stdin.puts(JSON.generate(context: context, options: options))
        reply = JSON.parse(@stdout.gets || raise(ConnectionError, "cua-s1 sidecar exited"))
        raise InvalidRequestError, "cua-s1: #{reply["error"]}" if reply["error"]

        reply.fetch("probabilities")
      rescue Errno::EPIPE
        close
        raise ConnectionError, "cua-s1 sidecar died"
      end

      def boot
        raise InvalidRequestError, "no checkpoint: set S1.config.cua.checkpoint" if @checkpoint.to_s.empty?

        @stdin, @stdout, @wait = Open3.popen2(*@command)
        first = @stdout.gets or raise ConnectionError, "cua-s1 sidecar failed to start (#{@command.join(" ")})"
        @config = JSON.parse(first).fetch("config")
      end
    end
  end
end
