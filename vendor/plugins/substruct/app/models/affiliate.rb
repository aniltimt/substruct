class Affiliate < ActiveRecord::Base
  SQL_VALID_ORDER_STATUS = "(order_status_code_id = 6 OR order_status_code_id = 7)"
  # Associations
  has_many :orders
  # Earned orders are valid referred orders.
  # The status codes here are 'ordered, paid, shipped' and 'sent to fulfillment'
  has_many :valid_referred_orders, 
    :class_name => 'Order', 
    :conditions => SQL_VALID_ORDER_STATUS
  has_many :orders_to_be_paid, 
    :class_name => 'Order', 
    :conditions => %q\
      #{SQL_VALID_ORDER_STATUS} 
      AND orders.created_on >= DATE_SUB(CURRENT_DATE(), INTERVAL #{Affiliate.get_paid_order_delay} DAY)
      AND orders.affiliate_payment_id  = 0
    \
  has_many :payments, 
    :class_name => 'AffiliatePayment',
    :dependent => :destroy
  # has_many :paid_orders
  # has_many :unpaid_orders
	# Validation
	validates_presence_of :code
	validates_uniqueness_of :code
	validates_format_of :code,
	  :with => /^[0-9a-zA-Z_-]+$/,
	  :message => "Affiliate code must only contain letters or numbers. No spaces or symbols."
  validates_presence_of :email_address, :message => ERROR_EMPTY
	validates_uniqueness_of :email_address, 
	  :message => "Affiliate email address already in use."
	validates_format_of :email_address,
	  :with => /^([^@\s]+)@((?:[-a-zA-Z0-9]+\.)+[a-zA-Z]{2,})$/,
	  :message => "Please enter a valid email address."
	
	# CLASS METHODS =============================================================
	
	# Finds Affiliates with total_owed > 0
	# TODO: Make more efficient. Will definitely bog down with
	# large numbers of affiliates.
	def self.find_unpaid
	  affiliates = find(
	    :all, 
	    :conditions => ["is_enabled = ?", true],
	    :include => [:orders]
	  )
	  affiliates.reject{|a| 0 >=  a.total_owed}
  end
	
	# Generates a 15 character alphanumeric code
	# that we use to track affiliates and promotions.
	def self.generate_code(size=10)
    # characters used to generate affiliate code
    chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890" 
    # create a new record object to satisfy while loop initially
    record = Object.new
    # loop through, creating random affiliate codes until
    # we create one that doesn't exist in the db
    while record        
      test_code = "" 
      srand
      size.times do
        pos = rand(chars.length)
        test_code += chars[pos..pos]
      end
      # find any affiliates with this same code string
      # if none are found the while loop exits
      record = find(:first, :conditions => ["code = ?", test_code])
    end
    # return our random code
    return test_code
  end
	
	# Authenticate an affiliate.
  #
  # Example:
  #   @a = Affiliate.authenticate('bob@somewhere.com', 'BOBCODE')
  def self.authenticate(email, code)
    find(
      :first,
      :conditions => [
        "email_address = ? AND code = ? AND is_enabled = ?", 
        email, code, true
      ]
    )
  end
  
  # Defines how long to wait before paying affiliates 
  # after an order has been processed.
  def self.get_paid_order_delay
    Preference.find_by_name('affiliate_paid_order_delay').value.to_i
  end
  # Defines what percentage of an order total to pay 
  # affiliate.
  def self.get_revenue_percentage
    Preference.find_by_name('affiliate_revenue_percentage').value.to_f
  end
  
  # INSTANCE METHODS ==========================================================
  
  # Gets months where affiliate has referred orders
  def get_earning_months
    orders = self.orders.find(:all, :select => ['created_on'])
    return orders.collect{|o| o.created_on.to_date.beginning_of_month }.uniq
  end
  
  # Sums earnings for get_earning_months
  def get_earnings()
    earnings = []
    self.get_earning_months.each do |month|
      earnings << self.get_earnings_for_month(month)
    end
    return earnings
  end
  
  def get_earnings_for_month(d)
    conds = [
      "created_on BETWEEN DATE(?) AND DATE(?)", 
      d.beginning_of_month, d.end_of_month
    ]
    orders = self.valid_referred_orders.find(:all, :conditions => conds)
    earnings = {
      :start_date => d,
      :num_total_orders => self.orders.count(:conditions => conds),
      :num_valid_orders => orders.size,
      :revenue => orders.inject(0.0){|sum,o| sum + o.total},
      :earnings => orders.inject(0.0){|sum,o| sum + o.affiliate_earnings}
    }
  end
  
  def total_earnings_this_month
    total = get_earnings_for_month(Date.today.beginning_of_month)[:earnings]
    total ||= 0.0
  end
  
  def total_earnings
    self.orders.find(:all).inject(0.0) do |sum,o| 
      sum + o.affiliate_earnings
    end 
  end
  
  def total_owed
    total = -(self.total_amount_paid - self.total_earnings)
    total ||= 0.0
  end
  
  def total_amount_paid
    total = self.payments.sum('amount')
    total ||= 0.0
  end
  
  def name
    if !self.company.blank?
      return self.company
    else
      return "#{self.first_name} #{self.last_name}"
    end
  end
  
end