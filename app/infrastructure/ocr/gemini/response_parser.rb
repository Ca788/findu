# frozen_string_literal: true

module Ocr
  module Gemini
    class ResponseParser
      include Llm::ResponseParsing
      # @param [RubyLLM::Message]
      # @param [Hash] metadata
      # @return [Ocr::Result]
      def call(response, metadata: {})
        data = parse_payload(response.content)
        Ocr::Result.new(
          amount: parse_decimal(data["amount"]),
          occurred_at: parse_time(data["occurred_at"]),
          description: data["description"],
          raw_text: data["raw_text"],
          confidence: data["confidence"],
          transaction_type: parse_transaction_type(data["transaction_type"]),
          metadata: metadata
        )
      end

      private

      # @param [String, Hash]
      # @return [Hash]
      def parse_payload(content)
        return content if content.is_a?(Hash)

        JSON.parse(content.to_s)
      rescue JSON::ParserError
        { "raw_text" => content.to_s, "confidence" => 0.0 }
      end
    end
  end
end
