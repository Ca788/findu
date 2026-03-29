class CreateInstallments < ActiveRecord::Migration[7.0]
  def change
    create_table :installments, id: :uuid do |t|
      t.references :transaction, type: :uuid, null: false, foreign_key: true
      t.decimal :total_amount, precision: 10, scale: 2
      t.integer :total_installments
      t.integer :current_installment
      t.decimal :monthly_amount, precision: 10, scale: 2
      t.datetime :started_at

      t.timestamps
    end
  end
end
