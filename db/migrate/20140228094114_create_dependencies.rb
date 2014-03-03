class CreateDependencies < ActiveRecord::Migration
  def change
    create_table :dependencies do |t|
      t.integer :project_id, null: false
      t.integer :library_id, null: false
      t.string :dependency_type, limit: 16
      t.string :requirement, limit: 16
    end
    add_index :dependencies, :project_id
    add_index :dependencies, :library_id
    add_index :dependencies, [:project_id, :library_id]
  end
end
