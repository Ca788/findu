# frozen_string_literal: true

module Llm
  module Schemas
    class InsightSchema < RubyLLM::Schema
      array :insights, description: "Insights financeiros acionáveis, do mais relevante para o menos.", max_items: 5 do
        object do
          string :content, description: "Insight em português brasileiro, uma ou duas frases, citando números reais do contexto."
          string :severity, description: "'info' para observação neutra, 'warning' para risco, 'critical' para problema urgente.", enum: %w[info warning critical]
          string :category_name, description: "Categoria relacionada ao insight, quando houver.", required: false
        end
      end
    end
  end
end
