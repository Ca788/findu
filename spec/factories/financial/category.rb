# frozen_string_literal: true

FactoryBot.define do
  factory :financial_category, class: "Financial::Category" do
    user
    name { Faker::Commerce.department(max: 1) }
  end
end
