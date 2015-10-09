require File.dirname(__FILE__) + '/../test_helper'

class AffiliateTest < ActiveSupport::TestCase
  fixtures :affiliates, :affiliate_payments, :orders, :preferences
  
  def setup
    @jm = affiliates(:joes_marketing)
  end
  
  # Makes all orders paid/shipped, belong to affiliate and spread
  # out across multiple months.
  def setup_earning_tests
    start_date = Date.today
    i = 0
    Order.find(:all).each do |o|
      o.update_attributes({
        :created_on => start_date - i.months,
        :order_status_code_id => 7,
        :affiliate => @jm
      })
      i += 1
    end
  end

  # ASSOCIATIONS ==============================================================
  
  def test_payments_destroyed
    payments = @jm.payments.find(:all)
    assert payments.size > 0
    assert @jm.destroy
    payments.each do |p|
      assert_nil AffiliatePayment.find_by_id(p.id)
    end
  end

  # VALIDATIONS ===============================================================
  
  def test_invalid_email_address_blank
    @jm.email_address = ''
    assert !@jm.valid?
    assert_error_on :email_address, @jm
  end

  def test_invalid_email_address_format
    @jm.email_address = "arthur.dent"
    assert !@jm.valid?
    assert_error_on :email_address, @jm
  end

  # An order user must have an unique email address.
  def test_invalid_email_address_unique
    @jm.email_address = affiliates(:bob_reseller).email_address
    assert !@jm.valid?
    assert_error_on :email_address, @jm
  end
  
  def test_valid_presence
    affil = Affiliate.new
    assert_valid_presence(@jm, :code)
  end
  
  def test_valid_uniqueness
    affil = Affiliate.new
    assert_valid_uniqueness(affil, @jm, :code)
  end
  
  def test_invalid_codes
    invalid_codes = [
      "code/with/slashes", "code?with?questionmarks",
      "code&with&ampersands", "code with spaces", "code's with apostrophes"
    ]
    invalid_codes.each do |code|
      @jm.code = code
      assert !@jm.save, "Saved with code: '#{code}' when it shouldn't have."
      assert_error_on :code, @jm
    end
  end
  
  def test_valid_codes
    valid_codes = [
      "code_with_underscores", "affiliate1", "joes_marketing",
      "code-with-dashes"
    ]
    5.times { valid_codes << Affiliate.generate_code }
    valid_codes.each do |code|
      @jm.code = code
      assert @jm.save, "Didn't save with code: '#{@jm.code}'"
    end
  end
  
  # ASSOCIATIONS --------------------------------------------------------------
  
  def test_valid_referred_orders
    orders = @jm.valid_referred_orders
    assert orders.size > 0
    orders.each do |o|
      assert o.order_status_code.id == 6 || o.order_status_code.id == 7
    end
  end
  
  def test_orders_to_be_paid
    payment_cutoff_date = Date.today - (Affiliate.get_paid_order_delay).days
    orders = @jm.orders_to_be_paid
    assert orders.size > 0
    orders.each do |o|
      assert o.created_on >= payment_cutoff_date
      assert_nil o.affiliate_payment, "Order was associated with AffiliatePayment when it shouldn't have been"
    end
  end

  # CLASS METHODS =============================================================
  
  def test_find_unpaid
    affiliates = Affiliate.find_unpaid()
    assert affiliates.size > 0
    affiliates.each do |a|
      assert a.total_owed > 0, "#{a.name} was included, even though they're not owed anything"
    end
  end
  
  def test_find_unpaid_disabled
    assert Affiliate.find_unpaid().size > 0
    assert Affiliate.update_all("is_enabled = 0")
    assert_equal 0, Affiliate.find_unpaid.size
  end
  
  def test_authenticate
    assert_kind_of Affiliate, Affiliate.authenticate(@jm.email_address, @jm.code)
    assert_nil Affiliate.authenticate(@jm.email_address, 'WRONG_CODE')
  end
  
  def test_authenticate_disabled
    assert @jm.is_enabled?
    assert_kind_of Affiliate, Affiliate.authenticate(@jm.email_address, @jm.code)
    assert @jm.update_attribute(:is_enabled, false)
    assert_nil Affiliate.authenticate(@jm.email_address, @jm.code)
  end
  
  # INSTANCE METHODS ==========================================================
  
  def test_get_earning_months
    setup_earning_tests()
    
    # Exercise
    earning_months = @jm.get_earning_months
    
    # Verify
    assert_kind_of Array, earning_months
    assert_equal Order.count, earning_months.size
    earning_months.each do |m|
      assert_kind_of Date, m
      assert_equal 1, m.day
    end
  end
  
  def test_get_earnings
    setup_earning_tests()
    # Exercise
    earnings = @jm.get_earnings
    # Verify
    assert_kind_of Array, earnings
    assert_equal @jm.get_earning_months.size, earnings.size
    last_date = Date.today + 1.day
    earnings.each do |period|
      assert_kind_of Hash, period
      # Ensure in descending date order
      assert last_date > period[:start_date]
      last_date = period[:start_date]
    end
  end
  
  def test_total_earnings_this_month
    assert_kind_of Float, @jm.total_earnings_this_month
  end
  
  def test_total_earnings_this_month_no_orders
    assert Order.destroy_all
    assert_equal 0.0, @jm.total_earnings_this_month
  end
  
  def test_amount_paid
    assert AffiliatePayment.destroy_all
    assert_equal 0.0, @jm.total_amount_paid
  end
  
  def test_total_owed
    assert AffiliatePayment.destroy_all
    assert_nothing_raised do
      assert_kind_of Float, @jm.total_owed
    end
  end
  
  def test_name
    assert @jm.company.blank?
    assert_equal "#{@jm.first_name} #{@jm.last_name}", @jm.name
    @jm.company = "Xyz Corp"
    assert_equal @jm.company, @jm.name
  end
  
  def test_name_no_first_last
    assert @jm.update_attributes({
      :first_name => nil,
      :last_name => nil,
      :company => nil
    })
    assert_nothing_raised { @jm.name }
  end
  
end