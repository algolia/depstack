class AddVotesCount < ActiveRecord::Migration
  def change
    add_column :libraries, :votes_count, :integer, null: false, default: 0
  end
end
