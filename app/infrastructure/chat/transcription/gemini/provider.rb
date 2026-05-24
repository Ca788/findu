# frozen_string_literal: true

module Chat
  module Transcription
    module Gemini
      class Provider
        DEFAULT_MODEL = "gemini-2.5-flash"

        # @param [Class]
        # @param [Llm::Prompts::AudioTranscriptionPromptBuilder]
        # @param [Chat::Transcription::Gemini::AudioResolver]
        def initialize(schema: Llm::Schemas::TranscriptionSchema,
                       prompt_builder: Llm::Prompts::AudioTranscriptionPromptBuilder.new,
                       audio_resolver: AudioResolver.new)
          @schema         = schema
          @prompt_builder = prompt_builder
          @audio_resolver = audio_resolver
        end

        # @param [String, IO, Tempfile, ActionDispatch::Http::UploadedFile]
        # @return [Chat::Transcription::Result]
        def transcribe(audio)
          path = @audio_resolver.call(audio)
          chat = RubyLLM.chat(model: model_name).with_schema(@schema)
          response = chat.ask(@prompt_builder.call, with: path)
          parse(response)
        end

        private

        # @param [RubyLLM::Message]
        # @return [Chat::Transcription::Result]
        def parse(response)
          data = parse_payload(response.content)
          Chat::Transcription::Result.new(
            transcript: data["transcript"].to_s,
            confidence: data["confidence"].to_f,
            metadata:   { provider: "gemini", model: model_name }
          )
        end

        def parse_payload(content)
          return content if content.is_a?(Hash)

          JSON.parse(content.to_s)
        rescue JSON::ParserError
          { "transcript" => content.to_s, "confidence" => 0.0 }
        end

        def model_name
          ENV.fetch("GEMINI_AUDIO_MODEL", DEFAULT_MODEL)
        end
      end
    end
  end
end
