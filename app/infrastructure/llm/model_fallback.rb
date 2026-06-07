# frozen_string_literal: true

module Llm
  module ModelFallback
    module_function

    # @param [Array<String>, String]
    # @yieldparam [String]
    # @return [Object]
    # @raise [RubyLLM::RateLimitError]
    def with_fallback(models)
      chain = Array(models).map(&:to_s).reject(&:empty?)
      raise ArgumentError, "model chain is empty" if chain.empty?

      last_error = nil
      chain.each_with_index do |model, index|
        return yield(model)
      rescue RubyLLM::RateLimitError => e
        last_error = e
        Rails.logger.warn(
          "[Llm::ModelFallback] rate limit on #{model} (#{index + 1}/#{chain.size})" \
          "#{"; trying next" unless index == chain.size - 1}"
        )
      end

      raise last_error
    end
  end
end
