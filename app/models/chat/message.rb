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

    enum role:   { user: "user", assistant: "assistant", system: "system" }, _prefix: :role
    enum kind:   { text: "text", audio: "audio" }, _prefix: :kind
    enum status: { pending: "pending", processing: "processing", completed: "completed", failed: "failed" }

    validates :role, :kind, :status, presence: true

    scope :not_deleted, -> { where(deleted_at: nil) }

    def soft_delete!
      update!(deleted_at: Time.current)
    end

    def deleted?
      deleted_at.present?
    end
  end
end
