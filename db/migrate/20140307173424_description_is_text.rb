class DescriptionIsText < ActiveRecord::Migration
  def change
    change_column :libraries, :description, :text
  end
end
