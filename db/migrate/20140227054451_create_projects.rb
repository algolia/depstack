class CreateProjects < ActiveRecord::Migration
  def change
    create_table :projects do |t|
      t.string :user, null: false
      t.string :name, null: false
      t.string :description, null: false
      t.string :language, limit: 16
      t.integer :fork_count, null: false, default: 0
      t.integer :watcher_count, null: false, default: 0
      t.string :dependency_manager
      t.text :dependencies
      t.datetime :created_at 
      t.datetime :updated_at
    end
    add_index :projects, [:user, :name]
  end
end
