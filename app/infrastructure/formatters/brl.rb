# frozen_string_literal: true

module Formatters
  module Brl
    module_function

    # @param [Numeric, BigDecimal, String, nil]
    # @return [String]
    def call(value)
      format("R$%.2f", value.to_f).gsub(".", ",")
    end
  end
end
