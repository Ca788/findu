class AddAgentIdToChatConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :chat_conversations, :agent_id, :string
    add_index :chat_conversations, :agent_id
  end
end
