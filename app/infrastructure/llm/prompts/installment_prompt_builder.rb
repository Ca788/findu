# frozen_string_literal: true

module Llm
  module Prompts
    class InstallmentPromptBuilder
      # @param [String] text
      # @param [Date] today
      # @return [String]
      def call(text:, today: Date.current)
        <<~PROMPT
          Você é um assistente financeiro. Extraia os dados de uma compra parcelada da mensagem do usuário.
          Hoje é #{today.iso8601}.

          Mensagem: "#{text}"

          Regras:
            - total_amount: valor total da compra (decimal).
            - total_installments: número de parcelas (inteiro).
            - monthly_amount: valor de cada parcela (decimal). Se não estiver explícito, retorne null e o sistema infere (total / parcelas).
            - description: o que foi comprado (curto, ex: "celular", "sofá").
            - started_at: data de início em ISO 8601. Null se não mencionado (sistema usa hoje).
            - confidence: 0.0 a 1.0.

          Exemplos:
            - "comprei celular 3000 em 10 vezes" → total_amount: 3000, total_installments: 10, monthly_amount: null, description: "celular".
            - "parcelei o sofá em 12x de 200" → total_amount: 2400, total_installments: 12, monthly_amount: 200, description: "sofá".
        PROMPT
      end
    end
  end
end
