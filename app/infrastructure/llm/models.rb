# frozen_string_literal: true

module Llm
  module Models
    DEFAULT_CHAIN = %w[
      gemini-3.5-flash
      gemini-3.1-flash-lite
      gemini-3.1-pro-preview
    ].freeze

    LABELS = {
      "gemini-3.5-flash"      => "Gemini 3.5 Flash",
      "gemini-3.1-flash-lite" => "Gemini 3.1 Flash Lite",
      "gemini-3.1-pro-preview" => "Gemini 3.1 Pro"
    }.freeze

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

    # Models exposed to the client for chat selection.
    # @return [Array<Hash>]
    def catalog
      chain("CHAT_AGENT_MODEL").map do |id|
        {
          id:          id,
          name:        LABELS[id] || id.tr("-", " ").split.map(&:capitalize).join(" "),
          description: id == chain("CHAT_AGENT_MODEL").first ? "Padrão" : nil
        }
      end
    end

    # Puts the preferred model first while keeping the rest as fallback.
    # @param [String, nil] preferred
    # @param [Array<String>] fallback_chain
    # @return [Array<String>]
    def prefer(preferred, fallback_chain = chain("CHAT_AGENT_MODEL"))
      return fallback_chain if preferred.blank?
      return fallback_chain unless fallback_chain.include?(preferred)

      [preferred] + fallback_chain.reject { |id| id == preferred }
    end
  end
end
