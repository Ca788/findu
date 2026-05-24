# frozen_string_literal: true

module Llm
  module Schemas
    class InstallmentSchema < RubyLLM::Schema
      number :total_amount,       description: "Total amount of the purchase (decimal, no currency symbol)."
      number :total_installments, description: "Number of installments (integer)."
      number :monthly_amount,     description: "Amount per installment (decimal). If not stated, leave null and it will be inferred from total/installments."
      string :description,        description: "Short description of what was bought (e.g. 'celular', 'sofá')."
      string :started_at,         description: "Start date in ISO 8601 (YYYY-MM-DD). Null if not mentioned (defaults to today)."
      number :confidence,         description: "How confident you are (0.0 to 1.0)."
    end
  end
end
