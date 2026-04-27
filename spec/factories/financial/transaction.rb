# frozen_string_literal: true

FactoryBot.define do
  factory :financial_transaction, class: "Financial::Transaction" do
    user
    amount           { Faker::Number.decimal(l_digits: 3, r_digits: 2) }
    transaction_type { %w[expense income].sample }
    description      { Faker::Commerce.product_name }
    occurred_at      { Time.current }

    trait :expense do
      transaction_type { "expense" }
    end

    trait :income do
      transaction_type { "income" }
    end

    trait :with_category do
      category { association :financial_category, user: user }
    end
  end
end
