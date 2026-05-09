# frozen_string_literal: true

module V1
  module Financial
    class SummarySerializer < Blueprinter::Base
      class CategoryBreakdownSerializer < Blueprinter::Base
        fields :category_id, :category_name, :amount
      end

      fields :total_amount, :transaction_count, :by_type

      association :by_category, blueprint: CategoryBreakdownSerializer
    end
  end
end
