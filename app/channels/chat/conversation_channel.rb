# frozen_string_literal: true

module Chat
  class ConversationChannel < ApplicationCable::Channel
    def subscribed
      conversation = current_user.chat_conversations.find_by(id: params[:conversation_id])
      return reject unless conversation

      stream_for conversation
    end

    def unsubscribed
      stop_all_streams
    end
  end
end
