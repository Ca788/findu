# frozen_string_literal: true

module Llm
  module Prompts
    class TransactionPromptBuilder
      # @param [String]
      # @param [Date]
      # @return [String]
      def call(text:, today: Date.current)
        <<~PROMPT
          You are a personal finance assistant. Extract a financial transaction from the user's message.
          Today's date is #{today.iso8601}.
          User message: "#{text}"
          Rules:
            - amount: the numeric value mentioned (no currency symbol, dot as decimal separator).
            - transaction_type: 'expense' if money was spent, 'income' if received. Default 'expense'.
            - description: what was bought or received.
            - occurred_at: date mentioned or null if not specified.
            - category: nome da categoria, curto e em minúsculas.
                * Se o usuário citar EXPLICITAMENTE ("categoria X", "categoria de X", "em X", "na conta de X"), use EXATAMENTE o nome que ele disse (ex: "categoria Uber" -> "uber"; "categoria farmácia" -> "farmácia"). Não substitua por sinônimo.
                * Se NÃO houver menção explícita mas o estabelecimento/contexto deixar a categoria óbvia, infira uma simples (ex: "comprei no iFood" -> "alimentação"; "paguei o Netflix" -> "assinaturas"; "fui no mercado" -> "mercado").
                * Retorne null quando não houver categoria clara nem mencionada.
            - confidence: 1.0 if all fields are clear, lower if you had to infer.
          Return null for fields you cannot determine.
        PROMPT
      end
    end
  end
end
