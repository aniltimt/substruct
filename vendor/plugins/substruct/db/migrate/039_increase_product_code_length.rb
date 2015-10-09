# Make product / item codes longer. 20 chars is not enough
class IncreaseProductCodeLength < ActiveRecord::Migration
  def self.up
    change_column :items, :code, :string, :limit => 100, :default => '', :null => false
  end
  
  def self.down
    change_column :items, :code, :string, :limit => 20, :default => '', :null => false
  end
end