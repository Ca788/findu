# frozen_string_literal: true

module Llm
  module ResponseParsing
    DEFAULT_FALLBACK_PAYLOAD = { "confidence" => 0.0 }.freeze

    # @param [String]
    # @param [Class]
    # @param [Array<String>]
    # @param [#call]
    # @param [Hash]
    # @return [Hash]
    def llm_extract(text:, schema:, models:, prompt_builder:, fallback: DEFAULT_FALLBACK_PAYLOAD)
      response = Llm::ModelFallback.with_fallback(models) do |model|
        Llm::GeminiChat.for(model).with_schema(schema).ask(prompt_builder.call(text: text))
      end
      parse_payload(response.content, fallback: fallback)
    end

    # @param [Object]
    # @param [Hash]
    # @return [Hash]
    def parse_payload(content, fallback: DEFAULT_FALLBACK_PAYLOAD)
      return content if content.is_a?(Hash)

      JSON.parse(content.to_s)
    rescue JSON::ParserError
      fallback
    end

    # @param [Object]
    # @return [BigDecimal, nil]
    def parse_decimal(value)
      return nil if value.nil?

      BigDecimal(value.to_s)
    rescue ArgumentError
      nil
    end

    # @param [Object]
    # @return [String]
    def parse_transaction_type(value)
      return "expense" unless value.to_s.in?(%w[expense income])

      value.to_s
    end

    # @param [Object]
    # @return [Time, nil]
    def parse_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    # @param [Object]
    # @return [Date, nil]
    def parse_date(value)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue Date::Error, ArgumentError, TypeError
      nil
    end
  end
end
