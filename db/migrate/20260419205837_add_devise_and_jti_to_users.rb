class AddDeviseAndJtiToUsers < ActiveRecord::Migration[7.0]
  def up
    add_column :users, :jti, :string

    execute <<~SQL
      UPDATE users SET jti = gen_random_uuid()::text WHERE jti IS NULL
    SQL

    change_column_null :users, :jti, false
    add_index :users, :jti, unique: true

    remove_column :users, :password_digest
  end

  def down
    add_column :users, :password_digest, :string
    remove_index :users, :jti
    remove_column :users, :jti
  end
end
