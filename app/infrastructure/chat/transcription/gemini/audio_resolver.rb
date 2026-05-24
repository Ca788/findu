# frozen_string_literal: true

module Chat
  module Transcription
    module Gemini
      class AudioResolver
        # @param [String, IO, Tempfile, ActionDispatch::Http::UploadedFile]
        # @return [String]
        def call(audio)
          return audio if audio.is_a?(String)
          return audio.path if audio.respond_to?(:path) && audio.path.present?

          raise ArgumentError, "Unsupported audio input: #{audio.class}"
        end
      end
    end
  end
end
