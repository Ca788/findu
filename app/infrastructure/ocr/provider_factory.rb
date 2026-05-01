# frozen_string_literal: true

module Ocr
  class ProviderFactory
    # @param [String] artifact_type
    # @return [Ocr::Provider]
    def self.build(artifact_type: "receipt")
      case ENV.fetch("OCR_PROVIDER", "gemini")
      when "stub"
        Stub::Provider.new
      when "gemini"
        Gemini::Provider.for(artifact_type)
      else
        raise "Unsupported OCR provider: #{ENV['OCR_PROVIDER']}"
      end
    end
  end
end
