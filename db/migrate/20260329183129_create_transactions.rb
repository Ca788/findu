class CreateTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :transactions, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :artifact, type: :uuid, foreign_key: true
      t.references :category, type: :uuid, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :transaction_type, null: false
      t.string :description
      t.datetime :occurred_at
      t.jsonb :metadata, default: {}

      t.timestamps
    end
  end
end
