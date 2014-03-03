class CreateLibraries < ActiveRecord::Migration
  def change
    create_table :libraries do |t|
      t.string :name, null: false
      t.string :info
      t.integer :downloads
      t.string :platform, limit: 16
      t.string :homepage_uri
      t.text :raw
    end
    add_index :libraries, :name
  end
end
