# frozen_string_literal: true

module Support
  module Phone
    module_function

    DEFAULT_COUNTRY = "55"

    # @param [String, nil]
    # @param [String]
    # @return [String, nil]
    def e164(raw, default_country: DEFAULT_COUNTRY)
      digits = raw.to_s.gsub(/\D/, "")
      return if digits.blank?

      digits = "#{default_country}#{digits}" if local_mobile?(digits, default_country)
      "+#{digits}"
    end

    # @param [String]
    # @param [String]
    # @return [Boolean]
    def local_mobile?(digits, default_country)
      digits.length.between?(10, 11) && !digits.start_with?(default_country)
    end
  end
end
