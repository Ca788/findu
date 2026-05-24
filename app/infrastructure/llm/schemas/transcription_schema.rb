# frozen_string_literal: true

module Llm
  module Schemas
    class TranscriptionSchema < RubyLLM::Schema
      string :transcript, description: "Verbatim transcript of the user's speech in Portuguese (pt-BR), with natural punctuation and numbers normalized to digits (e.g. 'cinquenta reais' -> '50 reais')."
      number :confidence, description: "How clear and complete the audio was, between 0.0 and 1.0. Lower it if the audio is noisy, muffled, truncated, or partially unintelligible."
    end
  end
end
