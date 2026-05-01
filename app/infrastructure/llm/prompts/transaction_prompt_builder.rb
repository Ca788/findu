# frozen_string_literal: true

module Llm
  module Prompts
    class TransactionPromptBuilder
      # @param [String]
      # @param [Date]
      # @return [String]
      def call(text:, today: Date.current)
        <<~PROMPT
          You are a personal finance assistant. Extract a financial transaction from the user's message.
          Today's date is #{today.iso8601}.
          User message: "#{text}"
          Rules:
            - amount: the numeric value mentioned (no currency symbol, dot as decimal separator).
            - transaction_type: 'expense' if money was spent, 'income' if received. Default 'expense'.
            - description: what was bought or received.
            - occurred_at: date mentioned or null if not specified.
            - confidence: 1.0 if all fields are clear, lower if you had to infer.
          Return null for fields you cannot determine.
        PROMPT
      end
    end
  end
end
