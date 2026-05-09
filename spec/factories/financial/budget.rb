# frozen_string_literal: true

FactoryBot.define do
  factory :financial_budget, class: "Financial::Budget" do
    user
    period_type  { "monthly" }
    period_start { Date.current.beginning_of_month }
    period_end   { Date.current.end_of_month }
    limit_amount { 1000.00 }

    trait :weekly do
      period_type  { "weekly" }
      period_start { Date.current.beginning_of_week }
      period_end   { Date.current.end_of_week }
    end

    trait :yearly do
      period_type  { "yearly" }
      period_start { Date.current.beginning_of_year }
      period_end   { Date.current.end_of_year }
    end
  end
end
