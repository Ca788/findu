# frozen_string_literal: true

module Chat
  module Transcription
    class ProviderFactory
      # @return [Object]
      def self.build
        case ENV.fetch("CHAT_TRANSCRIPTION_PROVIDER", "gemini")
        when "gemini"
          Gemini::Provider.new
        else
          raise "Unsupported chat transcription provider: #{ENV['CHAT_TRANSCRIPTION_PROVIDER']}"
        end
      end
    end
  end
end
