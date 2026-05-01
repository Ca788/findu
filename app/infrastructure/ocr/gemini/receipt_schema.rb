# frozen_string_literal: true

module Ocr
  module Gemini
    class ReceiptSchema < RubyLLM::Schema
      number :amount, description: "Total amount paid (decimal, no currency symbol)"
      string :occurred_at, description: "Transaction date in ISO 8601 format (YYYY-MM-DD or full timestamp). Null if not visible."
      string :description, description: "Vendor or merchant name plus a short description (e.g. 'Posto Shell - combustivel')"
      string :raw_text, description: "Full raw text extracted from the receipt/screenshot"
      number :confidence, description: "Self-reported confidence between 0.0 and 1.0"
      string :transaction_type, description: "'expense' for purchases and payments, 'income' for refunds, cashbacks or received payments. Default 'expense' when unclear."
    end
  end
end
