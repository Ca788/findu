# frozen_string_literal: true

module Ocr
  class ProviderFactory
    # @return [Ocr::Provider]
    def self.build
      case ENV.fetch("OCR_PROVIDER", "gemini")
      when "stub"
        Stub::Provider.new
      when "gemini"
        Gemini::Provider.new
      else
        raise "Unsupported OCR provider: #{ENV['OCR_PROVIDER']}"
      end
    end
  end
end
