class DescriptionIsTextWithout255Limit < ActiveRecord::Migration
  def change
    change_column :libraries, :description, :text, limit: 8192
  end
end
