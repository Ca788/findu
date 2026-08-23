# frozen_string_literal: true

module Support
  module DateParser
    module_function

    MONTH_PATTERN = /\A\d{4}-\d{2}\z/

    # @param [String, Date, DateTime, Time, nil]
    # @return [Date, nil]
    def parse(value)
      return nil  if value.blank?
      return value.to_date if value.respond_to?(:to_date) && !value.is_a?(String)

      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    # @param [String, Date, DateTime, Time, nil]
    # @return [Date, nil]
    def parse_month(value)
      if value.is_a?(String) && value.match?(MONTH_PATTERN)
        year, month = value.split("-").map(&:to_i)
        return Date.new(year, month, 1)
      end

      parse(value)&.beginning_of_month
    end
  end
end
