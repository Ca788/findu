# frozen_string_literal: true

module V1
  module Financial
    class BudgetSerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :period_type, :period_start, :period_end, :limit_amount
      end

      view :extended do
        include_view :default
        fields :created_at, :updated_at
      end
    end
  end
end
