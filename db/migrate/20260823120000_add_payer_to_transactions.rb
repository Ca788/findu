# frozen_string_literal: true

class AddPayerToTransactions < ActiveRecord::Migration[7.0]
  def change
    add_column :transactions, :payer_name, :string
    add_column :transactions, :payer_phone, :string

    add_index :transactions, [:user_id, :payer_phone]
  end
end
