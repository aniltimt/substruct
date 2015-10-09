require File.dirname(__FILE__) + '/../test_helper'

class AffiliatePaymentTest < ActiveSupport::TestCase
  fixtures :affiliates, :affiliate_payments, :orders, :preferences
  
  def setup
    @ap = affiliate_payments(:joe_today)
    @affil = affiliates(:joes_marketing)
  end

  # ASSOCIATIONS ==============================================================
  
  def test_nullify_orders_after_destroy
    p = AffiliatePayment.new_for(@affil)
    assert p.save
    orders = p.orders
    assert orders.size > 0
    # Exercise
    assert p.destroy
    # Verify
    orders.each do |o|
      assert_equal 0, o.reload.affiliate_payment_id
    end
  end

  # CLASS METHODS =============================================================
  
  def test_new_for_affiliate_owed
    expected_owed = @affil.total_owed
    assert expected_owed > 0
    # Exercise
    p = AffiliatePayment.new_for(@affil)
    # Verify
    assert_equal expected_owed, p.amount 
    assert_equal @affil, p.affiliate
    assert p.orders.size > 0
    # Save & verify
    assert p.save
    assert_equal 0, @affil.reload.total_owed
    assert_equal 0, @affil.orders_to_be_paid.find(:all).size
  end
  
  # If nothing is owed, why should we make a payment?
  def test_new_for_affiliate_nothing_owed
    affil = affiliates(:bob_reseller)
    assert_equal 0, affil.total_owed
    # Exercise / Verify
    assert_nil AffiliatePayment.new_for(affil)
  end
  
  # Disabled affiliates not eligible for payments
  def test_new_for_affiliate_disabled
    assert @affil.total_owed > 0
    assert @affil.update_attribute(:is_enabled, false)
    assert_nil AffiliatePayment.new_for(@affil)
  end

  def test_new_for_all_unpaid
    unpaid_affiliates = Affiliate.find_unpaid
    assert unpaid_affiliates.size > 0
    payments = AffiliatePayment.new_for_all_unpaid
    assert_equal unpaid_affiliates.size, payments.size
    payments.each do |p|
      assert p.new_record?
      assert_not_nil p.created_at
    end
  end
  
  # Disabled affiliates not eligible for payments
  def test_new_for_all_unpaid_disabled
    assert Affiliate.update_all("is_enabled = 0")
    payments = AffiliatePayment.new_for_all_unpaid
    assert_equal 0, payments.size
  end
  
  def test_get_csv_for
    csv = AffiliatePayment.get_csv_for([@ap])
    assert_kind_of String, csv 
  end

  # INSTANCE METHODS ==========================================================
  
  def test_valid_presence
    p = AffiliatePayment.new
    assert_valid_presence(p, :amount)
  end
  
  def test_number
    assert_equal "PMT-#{@ap.id}", @ap.number
  end
  
end