# Adds a rank field used for sorting item variations
class AddVariationRank < ActiveRecord::Migration
  def self.up
    add_column :items, :variation_rank, :integer, :limit => 3
  end
  
  def self.down
    remove_column :items, :variation_rank
  end
end