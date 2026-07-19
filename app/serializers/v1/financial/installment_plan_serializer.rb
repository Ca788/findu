# frozen_string_literal: true

module V1
  module Financial
    class InstallmentPlanSerializer < Blueprinter::Base
      identifier :id

      view :default do
        fields :description, :transaction_type, :category_id,
               :total_installments, :monthly_amount, :first_competency,
               :status, :started_at, :canceled_at, :created_at, :updated_at

        field(:total_amount)     { |p| p.total_amount_derived }
        field(:paid_count)       { |p| p.paid_count }
        field(:remaining_count)  { |p| p.remaining_count }
        field(:paid_amount)      { |p| p.paid_amount }
        field(:remaining_amount) { |p| p.remaining_amount }
        field(:end_competency)   { |p| p.end_competency }
      end

      view :extended do
        include_view :default

        association :category, blueprint: V1::Financial::CategorySerializer, view: :default
      end
    end
  end
end
