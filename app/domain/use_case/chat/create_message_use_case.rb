# frozen_string_literal: true

class UseCase::Chat::CreateMessageUseCase
  # @param [Chat::Conversation]
  # @param [User]
  # @param [String, nil]
  # @param [ActionDispatch::Http::UploadedFile, nil]
  # @param [String, nil]
  # @return [Chat::Message]
  def call(conversation:, user:, body: nil, audio: nil, client_message_id: nil)
    raise ArgumentError, "body or audio is required" if body.blank? && audio.blank?

    if client_message_id.present?
      existing = user.chat_messages.find_by(client_message_id: client_message_id)
      return existing if existing
    end

    kind = audio.present? ? "audio" : "text"

    message = conversation.messages.create!(
      user:              user,
      role:              "user",
      kind:              kind,
      status:            "pending",
      body:              body,
      client_message_id: client_message_id
    )

    message.audio.attach(audio) if audio.present?

    Chat::ProcessMessageJob.perform_later(message)

    message
  end
end
