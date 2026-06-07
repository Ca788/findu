# frozen_string_literal: true

class UseCase::Chat::CreateMessageUseCase
  # @param [Chat::Conversation]
  # @param [User]
  # @param [String, nil]
  # @param [ActionDispatch::Http::UploadedFile, nil]
  # @param [Array<ActionDispatch::Http::UploadedFile>]
  # @param [String, nil]
  # @return [Chat::Message]
  def call(conversation:, user:, body: nil, audio: nil, attachments: [], client_message_id: nil)
    attachments = Array(attachments).compact_blank
    if body.blank? && audio.blank? && attachments.empty?
      raise ArgumentError, "body, audio or attachments are required"
    end

    if client_message_id.present?
      existing = user.chat_messages.find_by(client_message_id: client_message_id)
      return existing if existing
    end

    kind = audio.present? ? "audio" : "text"

    message = conversation.messages.new(
      user:              user,
      role:              "user",
      kind:              kind,
      status:            "pending",
      body:              body,
      client_message_id: client_message_id
    )

    message.audio.attach(audio) if audio.present?
    message.attachments.attach(attachments) if attachments.any?

    message.save!

    conversation.broadcast_message!(message)
    Chat::ProcessMessageJob.perform_later(message)

    message
  end
end
