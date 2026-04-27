class RemoveParentFromCategories < ActiveRecord::Migration[7.0]
  def up
    remove_foreign_key :categories, column: :parent_id
    remove_index :categories, :parent_id
    remove_column :categories, :parent_id
  end

  def down
    add_column :categories, :parent_id, :uuid
    add_index :categories, :parent_id
    add_foreign_key :categories, :categories, column: :parent_id
  end
end
