# frozen_string_literal: true

module Llm
  module Schemas
    class TransactionSchema < RubyLLM::Schema
      number :amount,           description: "Transaction amount (decimal, no currency symbol). Null if not mentioned."
      string :transaction_type, description: "'expense' for money spent, 'income' for money received. Default 'expense'."
      string :description,      description: "Short description of what was bought or received (max 60 chars)."
      string :occurred_at,      description: "Date in ISO 8601 (YYYY-MM-DD). Null if not mentioned."
      string :category,         description: "Category name (short, lowercase preferred) when the user explicitly mentions it (e.g. 'categoria X', 'em transporte') OR when a clear, simple category can be inferred from the merchant/context (e.g. 'Uber' -> 'transporte', 'iFood' -> 'alimentação', 'mercado' -> 'mercado'). Null when no clear category."
      number :confidence,       description: "How confident you are in the extraction (0.0 to 1.0)."
    end
  end
end
