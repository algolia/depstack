class CreateLibraries < ActiveRecord::Migration
  def change
    create_table :libraries do |t|
      t.integer :manager_cd, null: false
      t.string :name, null: false
      t.string :platform, limit: 16
      t.string :description
      t.integer :downloads
      t.string :homepage_uri
      t.string :repository_uri
    end
    add_index :libraries, [:manager_cd, :name]
  end
end
