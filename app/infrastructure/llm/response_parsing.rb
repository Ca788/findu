# frozen_string_literal: true

module Llm
  module ResponseParsing
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
  end
end
