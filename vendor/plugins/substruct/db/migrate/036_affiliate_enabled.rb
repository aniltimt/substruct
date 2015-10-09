class AffiliateEnabled < ActiveRecord::Migration
  def self.up
		add_column :affiliates, :is_enabled, :boolean, :default => false
		add_column :affiliates, :created_at, :datetime
  end

  def self.down
		remove_column :affiliates, :is_enabled
		remove_column :affiliates, :created_at
  end
end