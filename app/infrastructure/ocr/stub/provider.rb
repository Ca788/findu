# frozen_string_literal: true

module Ocr
  module Stub
    class Provider < Ocr::Provider
      def extract(_image)
        Ocr::Result.new(
          amount: 42.50,
          occurred_at: Time.current,
          description: "Stubbed receipt",
          raw_text: "STUB OCR OUTPUT",
          confidence: 1.0,
          transaction_type: "expense",
          metadata: { provider: "stub" }
        )
      end
    end
  end
end
