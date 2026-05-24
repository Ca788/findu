# frozen_string_literal: true

module Llm
  module Prompts
    class CategoryPromptBuilder
      # @param [String] text
      # @return [String]
      def call(text:)
        <<~PROMPT
          Extraia o nome de uma categoria financeira que o usuário quer criar.
          Mensagem: "#{text}"

          Regras:
            - name: nome curto, em português, preferencialmente em minúsculas. Sem prefixos como "categoria de" ou "para".
            - confidence: 0.0 a 1.0. Baixa se a mensagem não for sobre criar categoria.

          Exemplos:
            - "criar categoria mercado" → name: "mercado"
            - "adicionar categoria saúde" → name: "saúde"
            - "nova categoria: transporte" → name: "transporte"
        PROMPT
      end
    end
  end
end
