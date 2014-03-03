class CreateDependencies < ActiveRecord::Migration
  def change
    create_table :dependencies do |t|
      t.integer :source_id, null: false
      t.integer :destination_id, null: false
      t.integer :environment_cd
      t.string :requirement, limit: 16
    end
    add_index :dependencies, :source_id
    add_index :dependencies, :destination_id
    add_index :dependencies, [:source_id, :destination_id]
  end
end
