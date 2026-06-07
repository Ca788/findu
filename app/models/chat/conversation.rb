# frozen_string_literal: true

# == Schema Information
#
# Table name: chat_conversations
#
#  id          :uuid             not null, primary key
#  archived_at :datetime
#  title       :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :uuid             not null
#
# Indexes
#
#  index_chat_conversations_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
module Chat
  class Conversation < ApplicationRecord
    self.table_name = "chat_conversations"

    belongs_to :user
    has_many :messages,
             class_name: "Chat::Message",
             foreign_key: :conversation_id,
             dependent: :destroy

    scope :active, -> { where(archived_at: nil) }

    def archived?
      archived_at.present?
    end

    def archive!
      update!(archived_at: Time.current)
    end

    # Broadcasts a message snapshot to subscribers of this conversation channel.
    # @param [Chat::Message] message
    # @return [void]
    def broadcast_message!(message)
      payload = ::V1::Chat::MessageSerializer.render_as_hash(message, view: :extended)
      Chat::ConversationChannel.broadcast_to(
        self,
        type:    "message.upserted",
        message: payload
      )
    end
  end
end
