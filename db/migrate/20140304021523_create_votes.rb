class CreateVotes < ActiveRecord::Migration
  def change
    create_table :votes do |t|
      t.integer :user_id, null: false
      t.integer :library_id, null: false
      t.datetime :created_at, null: false
    end
    add_index :votes, :user_id
    add_index :votes, :library_id
    add_index :votes, [:user_id, :library_id]
  end
end
