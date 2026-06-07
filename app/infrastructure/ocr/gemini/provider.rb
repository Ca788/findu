# frozen_string_literal: true

module Ocr
  module Gemini
    class Provider
      STRATEGIES = {
        "receipt" => { schema: Llm::Schemas::ReceiptSchema,
                       prompt_builder: Llm::Prompts::ReceiptPromptBuilder.new }
      }.freeze

      # @param [String]
      # @return [Ocr::Gemini::Provider]
      def self.for(artifact_type)
        strategy = STRATEGIES.fetch(artifact_type) { STRATEGIES["receipt"] }
        new(**strategy)
      end

      # @param [Class]
      # @param [Ocr::Gemini::PromptBuilder]
      # @param [Ocr::Gemini::ResponseParser]
      # @param [Ocr::Gemini::ImageResolver]
      def initialize(schema: Llm::Schemas::ReceiptSchema,
                     prompt_builder: Llm::Prompts::ReceiptPromptBuilder.new,
                     response_parser: ResponseParser.new,
                     image_resolver: ImageResolver.new)
        @schema = schema
        @prompt_builder = prompt_builder
        @response_parser = response_parser
        @image_resolver = image_resolver
      end

      # @param [String, IO, ActionDispatch::Http::UploadedFile]
      # @return [Ocr::Result]
      def extract(image)
        path = @image_resolver.call(image)
        used_model = nil
        response = Llm::ModelFallback.with_fallback(models) do |model|
          used_model = model
          Llm::GeminiChat.for(model).with_schema(@schema).ask(@prompt_builder.call, with: path)
        end
        @response_parser.call(response, metadata: { provider: "gemini", model: used_model })
      end

      private

      # @return [Array<String>]
      def models
        Llm::Models.chain("GEMINI_OCR_MODEL")
      end
    end
  end
end
