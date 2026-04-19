# frozen_string_literal: true

module Ocr
  Result = Struct.new(
    :amount,
    :occurred_at,
    :description,
    :raw_text,
    :confidence,
    :metadata,
    keyword_init: true
  ) do
    def initialize(amount: nil, occurred_at: nil, description: nil, raw_text: nil, confidence: nil, metadata: {})
      super
    end
  end
end
