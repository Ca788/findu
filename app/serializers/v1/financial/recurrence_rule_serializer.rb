# frozen_string_literal: true

module V1
  module Financial
    class RecurrenceRuleSerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :transaction_type, :amount, :description, :frequency,
               :day_of_month, :starts_on, :ends_on, :active,
               :category_id, :canceled_at, :created_at, :updated_at
      end

      view :extended do
        include_view :default

        association :category, blueprint: V1::Financial::CategorySerializer, view: :default
      end
    end
  end
end
