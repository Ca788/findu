# frozen_string_literal: true

module Ocr
  class ProviderFactory
    # @param [String]
    # @return [Ocr::Provider]
    def self.build(artifact_type: "receipt")
      case ENV.fetch("OCR_PROVIDER", "gemini")
      when "gemini"
        Gemini::Provider.for(artifact_type)
      else
        raise "Unsupported OCR provider: #{ENV['OCR_PROVIDER']}"
      end
    end
  end
end
