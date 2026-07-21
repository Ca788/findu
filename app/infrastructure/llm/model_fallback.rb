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
      rescue RubyLLM::RateLimitError, RubyLLM::Error => e
        last_error = e
        retryable = e.is_a?(RubyLLM::RateLimitError) || unavailable_model?(e)
        raise e unless retryable && index < chain.size - 1

        Rails.logger.warn(
          "[Llm::ModelFallback] #{e.class.name.demodulize} on #{model} " \
          "(#{index + 1}/#{chain.size}); trying next"
        )
      end

      raise last_error
    end

    def unavailable_model?(error)
      message = error.message.to_s.downcase
      message.include?("no longer available") ||
        message.include?("not found") ||
        message.include?("is not found") ||
        message.include?("invalid model")
    end
  end
end
