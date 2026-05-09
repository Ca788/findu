# frozen_string_literal: true

module Support
  module DateParser
    module_function

    # @param [String, Date, DateTime, Time, nil] value
    # @return [Date, nil]
    def parse(value)
      return nil  if value.blank?
      return value.to_date if value.respond_to?(:to_date) && !value.is_a?(String)

      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
