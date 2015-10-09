require File.dirname(__FILE__) + '/../test_helper'

class PromotionCheckoutTest < ActionController::IntegrationTest
  fixtures :all
  
  def setup
    # Setup & pre-verify
    @customer = order_users(:santa)
    @expensive_item = items(:grey_coat)
    @inexpensive_item = items(:lightsaber)
    @promo = promotions(:minimum_rebate)
  end

  def test_promo_minimum_cart_value    
    assert @promo.minimum_cart_value > @inexpensive_item.price
    post '/store/add_to_cart', :id => @inexpensive_item.id
    assert_redirected_to '/store/checkout'
    assert_equal assigns(:order).items.length, 1
    
    perform_successful_checkout()
    follow_redirect!
    assert_nil assigns(:order).promotion, "Promotion applied when it shouldn't have been."
  end

  # Ensure that customers can't circumvent the 'minimum cart value'
  # requirement for promotions by...
  #   * Adding products to exceed the limit
  #   * Filling out the checkout form and applying a promotion
  #   * Removing products from their cart
  #   * Hitting the "shipping method" screen
  #   * Checking out
  def test_promo_minimum_cart_value_bug
    # Setup & pre-verify
    assert (@expensive_item.price + @inexpensive_item.price) >= @promo.minimum_cart_value
    assert @promo.minimum_cart_value > @inexpensive_item.price
    
    get '/store'
    assert_response :success
    
    # ADD ITEMS TO CART
    add_items_to_cart()
    
    # FILL OUT CHECKOUT FORM SUCCESSFULLY
    perform_successful_checkout()
    follow_redirect!
    
    # ENSURE PROMO IS APPLIED
    assert_equal @promo, assigns(:order).promotion
    
    # REMOVE EXPENSIVE ITEM FROM CART
    xml_http_request(:post, '/store/remove_from_cart_ajax', {:id => @expensive_item.id})
    assert_response :success
    
    # HIT SHIPPING METHOD PAGE
    get '/store/select_shipping_method'
    assert_response :success
    
    # VERIFY PROMO NOT APPLIED
    assert_nil assigns(:order).promotion, "Promotion still applied when it shouldn't be."
    assert_equal @inexpensive_item.price, assigns(:order).line_items_total
  end
  
  # Ensures customers can't add expensive items to their 
  # cart, apply a promo, then remove one and have the promo with a minimum
  # value still apply.
  def test_double_promo_bug
    @promo.update_attribute(:minimum_cart_value, @expensive_item.price-1)
    
    # ADD ITEMS TO CART
    xml_http_request(:post, '/store/add_to_cart_ajax', {:id => @expensive_item.id})
    assert_response :success
    
    # FILL OUT FORM UNSUCCESSFULLY WITH PROMO APPLIED
    perform_unsuccessful_checkout()
    assert_equal @promo, assigns(:order).promotion

    # FILL OUT FORM UNSUCCESSFULLY WITH PROMO APPLIED
    perform_unsuccessful_checkout()
    assert_equal @promo, assigns(:order).promotion
    
    # CHECK ONLY ONE PROMO LINE ITEM APPLIED
    o = assigns(:order)
    assert o.order_line_items.delete(o.promotion_line_item)
    assert_nil o.promotion_line_item, "Found more than one promotion line item."
  end
  
  private
    # Submit the 'checkout' action with a promo code, unsuccessfully
    def perform_unsuccessful_checkout
      post(
        '/store/checkout', 
        {
          :order_account => {
            :cc_number => "4007000000027",
            :expiration_year => (Date.today - 1.year).year,
            :expiration_month => "1"
          },
          :shipping_address => @customer.billing_address.attributes,
          :billing_address => @customer.billing_address.attributes,
          :order_user => {
            :email_address => @customer.email_address
          },
          :order => {
            :promotion_code => @promo.code
          }
        }
      )
      assert_response :success
      assert_template 'checkout'
      assert !flash.now[:notice].blank?
    end
  
    # Submit the 'checkout' action successfully, but with a fake CC# 
    # and valid promo code.
    def perform_successful_checkout_bad_card
      post(
        '/store/checkout', 
        {
          :order_account => {
            :cc_number => "1111111111111111",
            :expiration_year => 4.years.from_now.year,
            :expiration_month => "1"
          },
          :shipping_address => @customer.billing_address.attributes,
          :billing_address => @customer.billing_address.attributes,
          :order_user => {
            :email_address => @customer.email_address
          },
          :order => {
            :promotion_code => @promo.code
          }
        }
      )
      assert_redirected_to :action => 'select_shipping_method'
    end
  
    # Submit the 'checkout' action successfully, but with a bad CC#.
    def perform_successful_checkout
      post(
        '/store/checkout', 
        {
          :order_account => {
            :cc_number => "1111111111111111",
            :expiration_year => 4.years.from_now.year,
            :expiration_month => "1"
          },
          :shipping_address => @customer.billing_address.attributes,
          :billing_address => @customer.billing_address.attributes,
          :order_user => {
            :email_address => @customer.email_address
          },
          :order => {
            :promotion_code => @promo.code
          }
        }
      )
      assert_redirected_to :action => 'select_shipping_method'
    end

    # Adds items to cart in order to meet the minimum value required by 
    # the promotion we're testing.
    def add_items_to_cart
      # Using both methods (ajax, non ajax) just to test legacy support.
      xml_http_request(:post, '/store/add_to_cart_ajax', {:id => @expensive_item.id})
      assert_response :success
      post '/store/add_to_cart', :id => @inexpensive_item.id
      assert_redirected_to '/store/checkout'
      assert_equal assigns(:order).items.length, 2   
    end
end