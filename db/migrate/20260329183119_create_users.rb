class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :role
      t.jsonb :settings, default: {}
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :users, [:organization_id, :email], unique: true
  end
end
