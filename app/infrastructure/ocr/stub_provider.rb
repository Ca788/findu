# frozen_string_literal: true

module Ocr
  class StubProvider < Provider
    def extract(_image)
      Result.new(
        amount: 42.50,
        occurred_at: Time.current,
        description: "Stubbed receipt",
        raw_text: "STUB OCR OUTPUT",
        confidence: 1.0,
        metadata: { provider: "stub" }
      )
    end
  end
end
