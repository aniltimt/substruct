class AffiliatePayments < ActiveRecord::Migration
  def self.up
    # AffiliatePayment - keeps track of payments made to Affiliates
		create_table "affiliate_payments" do |t|
		  t.column "number", :string
		  t.column "created_at", :datetime
		  t.column "affiliate_id", :integer, :default => 0, :null => false
		  t.column "amount", :float, :default => 0.0, :null => false
		  t.column "notes", :text
		end
		
		# Associates orders with AffiliatePayment so we know what's been paid
		add_column :orders, :affiliate_payment_id, :integer, :default => 0, :null => false
		
		# Add Tax ID to affiliate record for accurate record keeping
		add_column :affiliates, :tax_id, :string
		add_column :affiliates, :company, :string
  end

  def self.down
		drop_table "affiliate_payments"
		remove_column :orders, :affiliate_payment_id
		remove_column :affiliates, :tax_id
		remove_column :affiliates, :company
  end
end