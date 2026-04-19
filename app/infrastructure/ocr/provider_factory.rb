# frozen_string_literal: true

module Ocr
  class ProviderFactory
    # @return [Ocr::Provider]
    def self.build
      case ENV.fetch("OCR_PROVIDER", "stub")
      when "stub"
        StubProvider.new
      # when "openai_vision"
      #   OpenaiVisionProvider.new
      # when "google_vision"
      #   GoogleVisionProvider.new
      else
        raise "Unsupported OCR provider: #{ENV['OCR_PROVIDER']}"
      end
    end
  end
end
