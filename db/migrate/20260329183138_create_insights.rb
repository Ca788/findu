class CreateInsights < ActiveRecord::Migration[7.0]
  def change
    create_table :insights, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :reference_type, null: false
      t.uuid :reference_id
      t.text :content
      t.string :severity
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :insights, :reference_type
  end
end
