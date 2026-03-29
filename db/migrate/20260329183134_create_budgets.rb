class CreateBudgets < ActiveRecord::Migration[7.0]
  def change
    create_table :budgets, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.integer :month, null: false
      t.integer :year, null: false
      t.decimal :limit_amount, precision: 10, scale: 2
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :budgets, [:user_id, :month, :year], unique: true
  end
end
