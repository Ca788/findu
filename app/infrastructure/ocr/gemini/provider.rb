# frozen_string_literal: true

module Ocr
  module Gemini
    class Provider < Ocr::Provider
      DEFAULT_MODEL = "gemini-2.5-flash"

      # @param [Ocr::Gemini::PromptBuilder] prompt_builder
      # @param [Ocr::Gemini::ResponseParser] response_parser
      # @param [Ocr::Gemini::ImageResolver] image_resolver
      def initialize(prompt_builder: PromptBuilder.new,
                     response_parser: ResponseParser.new,
                     image_resolver: ImageResolver.new)
        @prompt_builder = prompt_builder
        @response_parser = response_parser
        @image_resolver = image_resolver
      end

      # @param [String, IO, ActionDispatch::Http::UploadedFile] image
      # @return [Ocr::Result]
      def extract(image)
        path = @image_resolver.call(image)
        chat = RubyLLM.chat(model: model_name).with_schema(ReceiptSchema)
        response = chat.ask(@prompt_builder.call, with: path)
        @response_parser.call(response, metadata: { provider: "gemini", model: model_name })
      end

      private

      # @return [String]
      def model_name
        ENV.fetch("GEMINI_OCR_MODEL", DEFAULT_MODEL)
      end
    end
  end
end
