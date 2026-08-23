# frozen_string_literal: true

FactoryBot.define do
  factory :financial_receipt, class: "Financial::Receipt" do
    user
    payer_name   { Faker::Name.name }
    payer_phone  { "+5511999999999" }
    period_start { Date.current.beginning_of_month }
    period_end   { Date.current.beginning_of_month }
    total_amount { 100 }
    status       { "pending" }

    trait :with_file do
      after(:build) do |receipt|
        receipt.file.attach(
          io:           StringIO.new("%PDF-1.4"),
          filename:     "comprovante.pdf",
          content_type: "application/pdf"
        )
      end
    end
  end
end
