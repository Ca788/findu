# frozen_string_literal: true

module Llm
  module Schemas
    class BudgetSchema < RubyLLM::Schema
      string :period_type, description: "One of: 'weekly', 'monthly', 'yearly', 'custom'.", enum: %w[weekly monthly yearly custom]
      string :period_start, description: "Period start date in ISO 8601 (YYYY-MM-DD)."
      string :period_end,   description: "Period end date in ISO 8601 (YYYY-MM-DD)."
      number :limit_amount, description: "Spending limit for the period (decimal, no currency symbol)."
      number :confidence,   description: "How confident you are (0.0 to 1.0)."
    end
  end
end
