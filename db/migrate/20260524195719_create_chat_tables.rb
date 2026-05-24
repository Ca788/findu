class CreateChatTables < ActiveRecord::Migration[7.0]
  def change
    create_table :chat_conversations, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: true
      t.string :title
      t.datetime :archived_at

      t.timestamps
    end

    create_table :chat_messages, id: :uuid do |t|
      t.references :conversation,
                   type: :uuid,
                   null: false,
                   foreign_key: { to_table: :chat_conversations },
                   index: true
      t.references :user, type: :uuid, null: false, foreign_key: true, index: true
      t.references :parent_message,
                   type: :uuid,
                   null: true,
                   foreign_key: { to_table: :chat_messages },
                   index: true
      t.string  :role,   null: false
      t.string  :kind,   null: false, default: "text"
      t.text    :body
      t.string  :status, null: false, default: "pending"
      t.string  :intent
      t.jsonb   :payload, default: {}
      t.jsonb   :error

      t.timestamps
    end

    add_index :chat_messages, :status
    add_index :chat_messages, :role
  end
end
