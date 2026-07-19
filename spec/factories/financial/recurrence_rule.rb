# frozen_string_literal: true

FactoryBot.define do
  factory :financial_recurrence_rule, class: "Financial::RecurrenceRule" do
    user
    transaction_type { "expense" }
    amount           { 100 }
    description      { "Aluguel" }
    frequency        { "monthly" }
    day_of_month     { 5 }
    starts_on        { Date.current.beginning_of_month }
    active           { true }
  end
end
