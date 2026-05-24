# frozen_string_literal: true

module Llm
  module Schemas
    class CategorySchema < RubyLLM::Schema
      string :name,       description: "Category name (short, lowercase preferred). Example: 'mercado', 'transporte', 'salário'."
      number :confidence, description: "How confident you are (0.0 to 1.0)."
    end
  end
end
