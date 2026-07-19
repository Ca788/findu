# frozen_string_literal: true

module V1
  module Financial
    class StatementSummarySerializer < Blueprinter::Base
      fields :month,
             :income_forecast, :expense_forecast, :balance_forecast,
             :income_paid,     :expense_paid,     :balance_actual,
             :pending_count,   :paid_count
    end
  end
end
