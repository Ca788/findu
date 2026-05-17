# frozen_string_literal: true

module V1
  module Financial
    class TransactionSerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :amount, :transaction_type, :description, :occurred_at, :category_id
      end

      view :extended do
        include_view :default
        fields :metadata, :artifact_id, :created_at, :updated_at, :budget_warnings

        association :category, blueprint: V1::Financial::CategorySerializer, view: :default
      end
    end
  end
end
