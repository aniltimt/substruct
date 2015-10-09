# Tracks payments made to Affiliates
class AffiliatePayment < ActiveRecord::Base
  has_many :orders, :dependent => :nullify
  belongs_to :affiliate
	validates_presence_of :amount
	
	# CLASS METHODS =============================================================
	
	# Makes single payment for an Affiliate
	def self.new_for(affil)
	  if affil.total_owed == 0 || !affil.is_enabled?
	    return nil 
    end
	  p = self.new(
	    :affiliate => affil,
	    :amount => affil.total_owed,
	    :orders => affil.orders_to_be_paid,
	    :created_at => Time.now
	  )
	  affil.orders_to_be_paid.each {|o| p.orders << o}
	  return p
  end
  
  # Makes payments for all unpaid Affiliates
  def self.new_for_all_unpaid
    payments = []
    affiliates = Affiliate.find_unpaid()
    affiliates.each do |a|
      p = AffiliatePayment.new_for(a)
      payments << p unless p.nil?
    end
    return payments
  end
  
  # Gets a CSV string that represents an order list.
  def self.get_csv_for(payment_list)
    require 'fastercsv'
    csv_string = FasterCSV.generate do |csv|
      payment_list.each do |p|
        affil = p.affiliate
        csv << [affil.email_address, p.amount, 'USD', p.number]
      end
    end
    return csv_string
  end
	
	# INSTANCE METHODS ==========================================================
	
	def number
	  "PMT-#{self.id}"
  end
end