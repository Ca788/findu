# frozen_string_literal: true

module V1
  module Financial
    class StatementSerializer < Blueprinter::Base
      class ByCategorySerializer < Blueprinter::Base
        fields :category_id, :category_name, :forecast, :paid
      end

      fields :month, :forecast, :actual, :counts

      association :entries,
                  blueprint: V1::Financial::TransactionSerializer,
                  view:      :default

      association :installments_active,
                  blueprint: V1::Financial::InstallmentPlanSerializer,
                  view:      :default

      association :recurrences_active,
                  blueprint: V1::Financial::RecurrenceRuleSerializer,
                  view:      :default

      association :by_category, blueprint: ByCategorySerializer
    end

    class StatementSummarySerializer < Blueprinter::Base
      fields :month,
             :income_forecast, :expense_forecast, :balance_forecast,
             :income_paid,     :expense_paid,     :balance_actual,
             :pending_count,   :paid_count
    end
  end
end
