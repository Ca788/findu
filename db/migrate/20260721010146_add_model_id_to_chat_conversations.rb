class AddModelIdToChatConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :chat_conversations, :model_id, :string
    add_index :chat_conversations, :model_id
  end
end
