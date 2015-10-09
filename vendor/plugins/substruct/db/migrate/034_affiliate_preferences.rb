class AffiliatePreferences < ActiveRecord::Migration
  def self.up
		# Add preferences for order payment delay & revenue percentage
    Preference.create(:name => 'affiliate_paid_order_delay', :value => '90')
    Preference.create(:name => 'affiliate_revenue_percentage', :value => '5')
  end

  def self.down
    Preference.destroy_all("name = 'affiliate_paid_order_delay'")
    Preference.destroy_all("name = 'affiliate_revenue_percentage'")
  end
end