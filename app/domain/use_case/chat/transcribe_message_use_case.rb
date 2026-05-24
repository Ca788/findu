# frozen_string_literal: true

class UseCase::Chat::TranscribeMessageUseCase
  # @param [Object, nil]
  def initialize(provider: nil)
    @provider = provider
  end

  # @param [Chat::Message]
  # @return [Chat::Transcription::Result]
  def call(message:)
    raise ArgumentError, "message has no attached audio" unless message.audio.attached?

    provider = @provider || Chat::Transcription::ProviderFactory.build

    result = message.audio.open do |tempfile|
      provider.transcribe(tempfile)
    end

    message.update!(body: result.transcript)
    result
  end
end
