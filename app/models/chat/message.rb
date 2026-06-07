# frozen_string_literal: true

# == Schema Information
#
# Table name: chat_messages
#
#  id                :uuid             not null, primary key
#  body              :text
#  deleted_at        :datetime
#  error             :jsonb
#  intent            :string
#  kind              :string           default("text"), not null
#  payload           :jsonb
#  role              :string           not null
#  status            :string           default("pending"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  client_message_id :uuid
#  conversation_id   :uuid             not null
#  parent_message_id :uuid
#  user_id           :uuid             not null
#
# Indexes
#
#  index_chat_messages_on_conversation_id             (conversation_id)
#  index_chat_messages_on_deleted_at                  (deleted_at)
#  index_chat_messages_on_parent_message_id           (parent_message_id)
#  index_chat_messages_on_role                        (role)
#  index_chat_messages_on_status                      (status)
#  index_chat_messages_on_user_and_client_message_id  (user_id,client_message_id) UNIQUE WHERE (client_message_id IS NOT NULL)
#  index_chat_messages_on_user_id                     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => chat_conversations.id)
#  fk_rails_...  (parent_message_id => chat_messages.id)
#  fk_rails_...  (user_id => users.id)
#
module Chat
  class Message < ApplicationRecord
    self.table_name = "chat_messages"

    belongs_to :conversation, class_name: "Chat::Conversation"
    belongs_to :user
    belongs_to :parent_message, class_name: "Chat::Message", optional: true
    has_many :replies,
             class_name: "Chat::Message",
             foreign_key: :parent_message_id,
             dependent: :nullify

    has_one_attached :audio, dependent: :purge_later
    has_many_attached :attachments, dependent: :purge_later

    ACCEPTED_ATTACHMENT_TYPES = %w[
      image/jpeg image/jpg image/png image/webp image/heic image/heif
      application/pdf
    ].freeze
    MAX_ATTACHMENT_SIZE_MB = 15
    MAX_ATTACHMENTS_PER_MESSAGE = 5

    enum role:   { user: "user", assistant: "assistant", system: "system" }, _prefix: :role
    enum kind:   { text: "text", audio: "audio" }, _prefix: :kind
    enum status: { pending: "pending", processing: "processing", completed: "completed", failed: "failed" }

    validates :role, :kind, :status, presence: true
    validate :acceptable_attachments

    scope :not_deleted, -> { where(deleted_at: nil) }

    def image_attachments
      attachments.select { |att| att.content_type.to_s.start_with?("image/") }
    end

    def document_attachments
      attachments.reject { |att| att.content_type.to_s.start_with?("image/") }
    end

    def soft_delete!
      update!(deleted_at: Time.current)
    end

    def deleted?
      deleted_at.present?
    end

    private

    def acceptable_attachments
      return unless attachments.attached?

      if attachments.size > MAX_ATTACHMENTS_PER_MESSAGE
        errors.add(:attachments, "no máximo #{MAX_ATTACHMENTS_PER_MESSAGE} arquivos por mensagem")
        return
      end

      max_bytes = MAX_ATTACHMENT_SIZE_MB.megabytes
      attachments.each do |att|
        unless ACCEPTED_ATTACHMENT_TYPES.include?(att.content_type.to_s)
          errors.add(:attachments, "tipo não suportado: #{att.content_type}")
        end
        errors.add(:attachments, "cada arquivo deve ter no máximo #{MAX_ATTACHMENT_SIZE_MB}MB") if att.byte_size > max_bytes
      end
    end
  end
end
