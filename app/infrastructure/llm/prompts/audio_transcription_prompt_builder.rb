# frozen_string_literal: true

module Llm
  module Prompts
    class AudioTranscriptionPromptBuilder
      # @return [String]
      def call
        <<~PROMPT
          Transcreva o áudio em português brasileiro.
          Regras:
            - transcript: texto literal do que foi dito, com pontuação natural. Normalize números falados para dígitos (ex: "cinquenta reais" -> "50 reais"; "duzentos e dez" -> "210").
            - confidence: 0.0 a 1.0. Reduza se o áudio estiver ruidoso, abafado, cortado ou parcialmente incompreensível.
          Não invente palavras que não foram ditas. Se não conseguir entender, retorne o que conseguiu transcrever e uma confidence baixa.
        PROMPT
      end
    end
  end
end
