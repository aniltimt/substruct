class RefactorContentNodes < ActiveRecord::Migration
  def self.up
    add_column :content_nodes, :user_id, :integer
    ContentNode.reset_column_information
    puts "Setting the first admin user as generator of all previous content"
    ContentNode.update_all("user_id = #{User.first.id}")
  end

  def self.down
		remove_column :content_nodes, :user_id
  end
end