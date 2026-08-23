# frozen_string_literal: true

module V1
  module Financial
    class CategoryTotalSerializer < Blueprinter::Base
      view :default do
        fields :category_id, :category_name, :income, :expense, :balance, :total
      end

      view :extended do
        include_view :default
        fields :paid_amount, :pending_amount, :transactions_count
      end
    end
  end
end
