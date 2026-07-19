# frozen_string_literal: true

module V1
  module Financial
    class TransactionSerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :amount, :transaction_type, :description,
               :occurred_at, :competency_month, :status, :paid_at,
               :category_id, :installment_number,
               :installment_plan_id, :recurrence_rule_id

        field(:source) { |t| t.source }
      end

      view :extended do
        include_view :default
        fields :metadata, :artifact_id, :created_at, :updated_at, :budget_warnings

        association :category, blueprint: V1::Financial::CategorySerializer, view: :default
      end
    end

    EntrySerializer = TransactionSerializer
  end
end
