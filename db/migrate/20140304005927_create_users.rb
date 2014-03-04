class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :login, null: false
      t.string :email
      t.string :name
      t.string :avatar_url
      t.datetime :created_at, null: false
    end
  end
end
