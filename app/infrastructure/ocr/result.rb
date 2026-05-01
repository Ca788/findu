# frozen_string_literal: true

module Ocr
  Result = Struct.new(
    :amount,
    :occurred_at,
    :description,
    :raw_text,
    :confidence,
    :transaction_type,
    :metadata,
    keyword_init: true
  )
end
