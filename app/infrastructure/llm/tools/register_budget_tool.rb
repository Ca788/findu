# frozen_string_literal: true

module Llm
  module Tools
    class RegisterBudgetTool < RubyLLM::Tool
      description "Cria um orçamento (limite de gastos) para um período. " \
                  "Use quando o usuário pedir para definir/ajustar limite, budget, ou orçamento."

      param :period_type, type: "string", desc: "'weekly', 'monthly', 'yearly' ou 'custom'."
      param :limit_amount, type: "number", desc: "Valor limite em reais (decimal)."
      param :period_start, type: "string", desc: "Início em ISO 8601 (YYYY-MM-DD). Se omitido, hoje.", required: false
      param :period_end, type: "string", desc: "Fim em ISO 8601 (YYYY-MM-DD). Se omitido, calculado pelo period_type.", required: false

      def initialize(user:, creator: UseCase::Financial::Budget::CreateBudgetUseCase.new)
        super()
        @user    = user
        @creator = creator
      end

      def execute(period_type:, limit_amount:, period_start: nil, period_end: nil)
        type  = %w[weekly monthly yearly custom].include?(period_type.to_s) ? period_type.to_s : "monthly"
        start = parsed_date(period_start) || Date.current
        finish = parsed_date(period_end) || default_end(start, type)

        budget = @creator.call(
          user:       @user,
          attributes: {
            period_type:  type,
            period_start: start,
            period_end:   finish,
            limit_amount: limit_amount
          }
        )

        {
          success:      true,
          budget_id:    budget.id,
          period_type:  budget.period_type,
          period_start: budget.period_start.to_s,
          period_end:   budget.period_end.to_s,
          limit_amount: budget.limit_amount.to_s
        }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def parsed_date(value)
        return nil if value.blank?

        Date.parse(value.to_s)
      rescue Date::Error, ArgumentError
        nil
      end

      def default_end(start, type)
        case type
        when "weekly"  then start + 6
        when "yearly"  then start.end_of_year
        when "custom"  then start + 30
        else                start.end_of_month
        end
      end
    end
  end
end
