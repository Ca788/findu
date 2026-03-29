class CreateCategories < ActiveRecord::Migration[7.0]
  def change
    create_table :categories, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.uuid :parent_id

      t.timestamps
    end

    add_foreign_key :categories, :categories, column: :parent_id
    add_index :categories, :parent_id
  end
end
