# frozen_string_literal: true

module Llm
  module Models
    DEFAULT_CHAIN = %w[
      gemini-3.5-flash
      gemini-3.1-flash-lite
      gemini-3.1-pro-preview
    ].freeze

    module_function

    # @param [String]
    # @return [Array<String>]
    def chain(env_key)
      raw = ENV[env_key].presence || ENV["GEMINI_MODEL_CHAIN"].presence
      return DEFAULT_CHAIN if raw.nil?

      parse(raw)
    end

    # @param [String]
    # @return [Array<String>]
    def parse(csv)
      models = csv.split(",").map(&:strip).reject(&:empty?)
      models.empty? ? DEFAULT_CHAIN : models
    end
  end
end
