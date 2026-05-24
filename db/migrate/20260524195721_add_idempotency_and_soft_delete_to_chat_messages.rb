class AddIdempotencyAndSoftDeleteToChatMessages < ActiveRecord::Migration[7.0]
  def change
    add_column :chat_messages, :client_message_id, :uuid
    add_index  :chat_messages, [:user_id, :client_message_id],
               unique: true,
               where: "client_message_id IS NOT NULL",
               name: "index_chat_messages_on_user_and_client_message_id"

    add_column :chat_messages, :deleted_at, :datetime
    add_index  :chat_messages, :deleted_at
  end
end
