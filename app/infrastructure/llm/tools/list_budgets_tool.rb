# frozen_string_literal: true

module Llm
  module Tools
    class ListBudgetsTool < BaseTool
      description "Lista os orçamentos vigentes do usuário em uma data de referência (padrão: hoje). " \
                  "Use quando o usuário pedir para ver/listar orçamentos, limites, ou para checar quanto " \
                  "ainda pode gastar."

      param :date, type: "string", desc: "Data de referência ISO 8601 (YYYY-MM-DD). Padrão: hoje.", required: false

      def initialize(user:, lister: UseCase::Financial::Budget::ListCurrentBudgetsUseCase.new)
        super()
        @user   = user
        @lister = lister
      end

      def execute(date: nil)
        safe_execute do
          result = @lister.call(user: @user, date: date.presence)
          {
            success:        true,
            reference_date: result.reference_date.iso8601,
            count:          result.budgets.size,
            budgets:        result.budgets.map { |b| serialize(b) }
          }
        end
      end

      private

      def serialize(budget)
        {
          id:            budget.id,
          period_type:   budget.period_type,
          period_start:  budget.period_start&.iso8601,
          period_end:    budget.period_end&.iso8601,
          limit_amount:  budget.limit_amount.to_s,
          spent_amount:  budget.spent_amount.to_s,
          remaining:     budget.remaining.to_s,
          usage_percent: budget.usage_percent
        }
      end
    end
  end
end
