# frozen_string_literal: true

class CreateReceipts < ActiveRecord::Migration[7.0]
  def change
    create_table :receipts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string  :payer_name
      t.string  :payer_phone, null: false
      t.date    :period_start, null: false
      t.date    :period_end,   null: false
      t.decimal :total_amount, precision: 10, scale: 2, null: false, default: 0
      t.string  :status, null: false, default: "pending"
      t.datetime :sent_at
      t.jsonb   :metadata, default: {}

      t.timestamps
    end

    add_index :receipts, [:user_id, :created_at]
    add_index :receipts, :status
  end
end
