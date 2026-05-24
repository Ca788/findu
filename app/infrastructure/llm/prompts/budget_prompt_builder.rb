# frozen_string_literal: true

module Llm
  module Prompts
    class BudgetPromptBuilder
      # @param [String] text
      # @param [Date] today
      # @return [String]
      def call(text:, today: Date.current)
        <<~PROMPT
          Você é um assistente financeiro. Extraia os dados de um orçamento (budget) da mensagem do usuário.
          Hoje é #{today.iso8601}.

          Mensagem: "#{text}"

          Regras:
            - period_type: 'weekly' (semana), 'monthly' (mês), 'yearly' (ano) ou 'custom' (datas específicas).
            - period_start / period_end: datas em ISO 8601 (YYYY-MM-DD).
                * Para 'monthly', use o primeiro e último dia do mês de referência (default: mês atual).
                * Para 'weekly', use segunda-feira a domingo da semana de referência.
                * Para 'yearly', use 1 de janeiro a 31 de dezembro do ano de referência.
                * Para 'custom', use as datas mencionadas na mensagem.
            - limit_amount: valor limite (decimal, sem símbolo de moeda).
            - confidence: 0.0 a 1.0.

          Se o usuário não mencionar período, assuma 'monthly' do mês atual.
          Se a mensagem não for sobre criar um orçamento, retorne confidence baixa.
        PROMPT
      end
    end
  end
end
