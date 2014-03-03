class RenameDependencyType < ActiveRecord::Migration
  def change
    rename_column :dependencies, :dependency_type, :environment
  end
end
