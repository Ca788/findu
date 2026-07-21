# frozen_string_literal: true

module Llm
  module Models
    DEFAULT_CHAIN = %w[
      gemini-3.5-flash
      gemini-3.1-flash-lite
      gemini-3.1-pro-preview
    ].freeze

    LABELS = {
      "gemini-3.5-flash"       => "Gemini 3.5 Flash",
      "gemini-3.1-flash-lite"  => "Gemini 3.1 Flash Lite",
      "gemini-3.1-pro-preview" => "Gemini 3.1 Pro"
    }.freeze

    module_function

    def chain(env_key)
      raw = ENV[env_key].presence || ENV["GEMINI_MODEL_CHAIN"].presence
      return DEFAULT_CHAIN if raw.nil?

      parse(raw)
    end

    def parse(csv)
      models = csv.split(",").map(&:strip).reject(&:empty?)
      models.empty? ? DEFAULT_CHAIN : models
    end

    def available(env_key = "CHAT_AGENT_MODEL")
      chain(env_key).map do |id|
        { id: id, name: LABELS[id] || id.tr("-", " ").split.map(&:capitalize).join(" ") }
      end
    end

    def prefer(preferred, env_key = "CHAT_AGENT_MODEL")
      base = chain(env_key)
      return base if preferred.blank?
      return base unless base.include?(preferred)

      [preferred] + base.reject { |id| id == preferred }
    end
  end
end
