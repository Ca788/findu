# frozen_string_literal: true

module Ocr
  module Gemini
    class PromptBuilder
      # @param [Date] today
      # @return [String]
      def call(today: Date.current)
        <<~PROMPT
          You are an OCR engine for personal finance receipts and payment screenshots.
          Today's date is #{today.iso8601} (use it as reference when inferring missing parts of dates).
          Extract the data into the provided JSON schema.
          Rules:
            - amount: numeric total paid by the user (no currency symbol, dot as decimal separator).
            - occurred_at: date the transaction happened, ISO 8601 (YYYY-MM-DD or full timestamp).
                * If the document shows only day and month (e.g. "Apr 22"), assume the year is #{today.year},
                  unless that would put the date in the future relative to today; in that case, use #{today.year - 1}.
                * Never invent a year that contradicts the receipt.
            - description: vendor / merchant + short context.
            - raw_text: copy as much text as possible from the document.
            - confidence: how sure you are about the extracted data (0.0 to 1.0).
            - transaction_type: 'expense' for money spent; 'income' for refunds, cashbacks or received payments. Default 'expense'.
          If a field cannot be determined, return null for that field (except raw_text, confidence and transaction_type).
        PROMPT
      end
    end
  end
end
