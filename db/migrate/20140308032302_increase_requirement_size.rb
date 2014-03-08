class IncreaseRequirementSize < ActiveRecord::Migration
  def change
    change_column :dependencies, :requirement, :string, limit: 32
  end
end
