class AddAffiliates < ActiveRecord::Migration
  def self.up
		# Adds a table for affiliates
		create_table "affiliates" do |t|
		  # Affiliate code is generated randomly and given to the affiliate
		  #
		  # This affiliate will give out the code, which people can enter while shopping.
		  #
		  t.column "code", :string, :limit => 15, :default => "", :null => false
      t.column "first_name", :string, :limit => 50, :default => "", :null => false
      t.column "last_name", :string, :limit => 50, :default => "", :null => false
      t.column "telephone", :string, :limit => 20
      t.column "address", :string, :default => "", :null => false
      t.column "city", :string, :limit => 50
      t.column "state", :string, :limit => 10
      t.column "zip", :string, :limit => 10
      t.column "email_address", :string, :limit => 50, :default => "", :null => false
		end
		
		add_column :orders, :affiliate_id, :integer, :default => 0, :null => false
		
		# Add permissions for admins to edit affiliates
		puts 'Creating Affiliate rights'
		rights = Right.create(
			[ 
				{ :name => 'Affiliates - Admin', :controller => 'affiliates', :actions => '*' }, 
				{ :name => 'Affiliates - CRUD', :controller => 'affiliates', :actions => 'new,create,edit,update,destroy' },
				{ :name => 'Affiliates - View', :controller => 'affiliates', :actions => 'index,list,search,edit,show' },
			]
		)
		puts 'Assigning rights to Admin role...'
		admin_role = Role.find_by_name('Administrator')
		admin_role.rights.clear
		admin_role.rights << Right.find(:all, :conditions => "name LIKE '%Admin'")
  end

  def self.down
		drop_table "affiliates"
		remove_column :orders, :affiliate_id
		#
		puts 'Removing affiliate rights'
		rights = Right.find(:all, :conditions => "name LIKE 'Affiliates%'")
		for right in rights
		  right.destroy
	  end
  end
end