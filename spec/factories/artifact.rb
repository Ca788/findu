# frozen_string_literal: true

FactoryBot.define do
  factory :artifact do
    user
    artifact_type { "receipt" }
    source        { "mobile" }
    status        { "pending" }
    occurred_at   { Time.current }
    processed_data { {} }
    raw_data       { {} }

    trait :processed do
      status { "processed" }
      processed_data do
        {
          "amount"      => "150.75",
          "description" => "Supermercado XYZ",
          "raw_text"    => "SUPERMERCADO XYZ LTDA TOTAL R$ 150,75",
          "confidence"  => 0.95,
          "metadata"    => {}
        }
      end
    end

    trait :failed do
      status { "failed" }
      processed_data { { "error" => { "class" => "RuntimeError", "message" => "OCR extraction failed" } } }
    end
  end
end
