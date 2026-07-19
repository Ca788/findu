# frozen_string_literal: true

FactoryBot.define do
  factory :financial_installment_plan, class: "Financial::InstallmentPlan" do
    user
    description        { "Celular" }
    transaction_type   { "expense" }
    total_installments { 5 }
    monthly_amount     { 500 }
    total_amount       { 2500 }
    first_competency   { Date.current.beginning_of_month }
    status             { "active" }
  end
end
