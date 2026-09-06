# frozen_string_literal: true

class AddCategoryIdToReceipts < ActiveRecord::Migration[7.0]
  def change
    add_reference :receipts, :category, type: :uuid, foreign_key: true, null: true
  end
end
