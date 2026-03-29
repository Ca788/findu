class CreateArtifacts < ActiveRecord::Migration[7.0]
  def change
    create_table :artifacts, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :artifact_type, null: false
      t.string :source
      t.jsonb :raw_data, default: {}
      t.jsonb :processed_data, default: {}
      t.string :status, default: 'pending'
      t.datetime :occurred_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :artifacts, :status
  end
end
