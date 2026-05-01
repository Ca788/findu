# frozen_string_literal: true

module Ocr
  module Gemini
    class ResponseParser
      # @param [RubyLLM::Message] response
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

      # @param [String, Hash] content
      # @return [Hash]
      def parse_payload(content)
        return content if content.is_a?(Hash)

        JSON.parse(content.to_s)
      rescue JSON::ParserError
        { "raw_text" => content.to_s, "confidence" => 0.0 }
      end

      # @param [Object] value
      # @return [BigDecimal, nil]
      def parse_decimal(value)
        return nil if value.nil?

        BigDecimal(value.to_s)
      rescue ArgumentError
        nil
      end

      # @param [Object] value
      # @return [String]
      def parse_transaction_type(value)
        return "expense" unless value.to_s.in?(%w[expense income])

        value.to_s
      end

      # @param [Object] value
      # @return [Time, nil]
      def parse_time(value)
        return nil if value.blank?

        Time.zone.parse(value.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
