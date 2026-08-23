# frozen_string_literal: true

module Llm
  module Prompts
    class InsightPromptBuilder
      MAX_CATEGORIES = 10

      PERSONA = <<~PERSONA.freeze
        Você é o analista financeiro do FindU. Gere insights curtos e acionáveis sobre as finanças do usuário.

        Regras:
          - Português brasileiro, tom honesto e prático, sem bajulação.
          - Use apenas os números fornecidos abaixo. Não invente dados.
          - Cada insight deve ser específico: cite valor, categoria ou percentual quando fizer sentido.
          - Evite repetir o mesmo assunto em insights diferentes.
          - severity: 'critical' para estouro de orçamento ou saldo negativo, 'warning' para tendência de risco,
            'info' para observações úteis.
          - Se não houver dados suficientes, retorne uma lista vazia.
      PERSONA

      # @param [UseCase::Chat::BuildUserContextUseCase::Context] context
      # @param [Array<UseCase::Financial::Category::ListCategoryTotalsUseCase::Total>] category_totals
      # @return [String]
      def call(context:, category_totals: [])
        [
          PERSONA,
          "DATA DE HOJE: #{context.reference_date.iso8601}",
          statement_section(context.statement),
          budgets_section(context.budgets),
          categories_section(category_totals)
        ].join("\n\n")
      end

      private

      def statement_section(statement)
        forecast = statement.forecast
        actual   = statement.actual
        counts   = statement.counts

        <<~SECTION.strip
          EXTRATO DE #{statement.month}:
            - Receitas previstas: #{Formatters::Brl.call(forecast[:income])} (pagas #{Formatters::Brl.call(actual[:income_paid])})
            - Despesas previstas: #{Formatters::Brl.call(forecast[:expense])} (pagas #{Formatters::Brl.call(actual[:expense_paid])})
            - Saldo previsto: #{Formatters::Brl.call(forecast[:balance])} (realizado #{Formatters::Brl.call(actual[:balance])})
            - Lançamentos: #{counts[:total]} (pendentes #{counts[:pending]}, pagos #{counts[:paid]})
        SECTION
      end

      def budgets_section(budgets)
        return "ORÇAMENTOS ATIVOS: nenhum orçamento vigente hoje." if budgets.blank?

        lines = budgets.map do |budget|
          "- #{budget.period_type.capitalize}: #{Formatters::Brl.call(budget.spent_amount)} de " \
            "#{Formatters::Brl.call(budget.limit_amount)} (#{budget.usage_percent}%), resta #{Formatters::Brl.call(budget.remaining)}"
        end

        "ORÇAMENTOS ATIVOS:\n#{lines.join("\n")}"
      end

      def categories_section(totals)
        return "TOTAIS POR CATEGORIA: nenhum lançamento categorizado no período." if totals.blank?

        lines = totals.first(MAX_CATEGORIES).map do |total|
          "- #{total.category_name}: receitas #{Formatters::Brl.call(total.income)}, " \
            "despesas #{Formatters::Brl.call(total.expense)}, pendente #{Formatters::Brl.call(total.pending_amount)} " \
            "(#{total.transactions_count} lançamentos)"
        end

        "TOTAIS POR CATEGORIA:\n#{lines.join("\n")}"
      end
    end
  end
end
