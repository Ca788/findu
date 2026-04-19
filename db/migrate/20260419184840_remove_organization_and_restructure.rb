class RemoveOrganizationAndRestructure < ActiveRecord::Migration[7.0]
  def up
    remove_foreign_key :artifacts, :organizations
    remove_foreign_key :budgets, :organizations
    remove_foreign_key :categories, :organizations
    remove_foreign_key :insights, :organizations
    remove_foreign_key :transactions, :organizations
    remove_foreign_key :users, :organizations

    remove_column :artifacts, :organization_id
    remove_column :budgets, :organization_id
    remove_column :insights, :organization_id
    remove_column :transactions, :organization_id

    remove_index :categories, :organization_id
    remove_column :categories, :organization_id
    add_reference :categories, :user, type: :uuid, null: false, foreign_key: true, index: true

    remove_index :users, [:organization_id, :email]
    remove_index :users, :organization_id
    remove_column :users, :organization_id
    remove_column :users, :role
    add_column :users, :password_digest, :string
    add_index :users, :email, unique: true

    drop_table :organizations
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
