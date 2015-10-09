require File.dirname(__FILE__) + '/../test_helper'

class StoreControllerTest < ActionController::TestCase
  fixtures :all

  # TODO: Appears that the cart and cart_container partials arent used, 
  # the cart partial is referenced in some places of store controller, 
  # but the actions can simply render nothing returning an state of success.
  #
  # In the views, the form_remote_tag or link_to_remote helper methods 
  # can simply ommit the update option, then an Ajax.Request object will
  # be created instead of an Ajax.Updater.
  #
  # Anyway a DOM node pointed by it is never manipulated, always an 
  # entire show_cart view inside the modal window is shown or reloaded,
  # using SUBMODAL.show() or window.location.reload() on complete. 
  
  def setup
    @santa_address = OrderAddress.find(order_addresses(:santa_address).id)
    @scrooge_address = OrderAddress.find(order_addresses(:uncle_scrooge_address).id)
  end


  # Test the index action.
  def test_index
    get :index
    assert_response :success
    assert_template 'index'
    assert_equal "Store", assigns(:title)
    assert_not_nil assigns(:tags)
    assert_not_nil assigns(:products)
  end
  
  def test_index_rss
    get :index, :format => 'rss'
    assert_response_rss
    assert_template 'index.rxml'
    assert_equal Product.count, assigns(:products).size
    assigns(:products).each do |item|
      assert item.is_published?, item.inspect
    end
  end
  
  def test_index_rss_products_hidden
    # Hide one product
    discontinued_item = items(:uranium_portion)
    assert discontinued_item.update_attribute(:date_available, Time.now + 1.week)
    assert !discontinued_item.is_published?
    # Make sure it doesn't show up on the RSS
    get :index, :format => 'rss'
    assert !assigns(:products).include?(discontinued_item)
  end

  # Affiliate code cookie gets written by JS.
  # Ensure it's applied to an order if we have that cookie present.
  def test_affiliate_code_cookie
    # Setup - write cookie
    affil = affiliates(:joes_marketing)
    @request.cookies['affiliate'] = affil.code
    # Exercise
    get :index
    assert_response :success
    # Verify
    assert_kind_of Order, assigns(:order)
    assert_equal affil.code, assigns(:order).affiliate_code
    assert_equal affil, assigns(:order).affiliate
  end

  # We should get a list of products using a search term.
  def test_search_multiple_results
    a_term = "an"
    get :search, :search_term => a_term
    assert_response :success
    assert_equal "Search Results for: #{a_term}", assigns(:title)
    # It should only list products, not variations.
    assert assigns(:products)
    assert_equal 2, assigns(:products).size
    assert_template 'index'
  end


  def test_search_one_result
    # Now with a term, that returns only one result.
    a_term = "lightsaber"
    get :search, :search_term => a_term
    assert_redirected_to :action => :show, :id => assigns(:products)[0].code
    assert assigns(:products)
    assert_equal 1, assigns(:products).size
  end


  def test_show_by_tags_no_tag
    get :show_by_tags, :tags => []
    assert_response :missing
  end

  # Now call it again with a tag.  
  def test_show_by_tags_with_tag
    a_tag = tags(:weapons)
    get :show_by_tags, :tags => [a_tag.name]
    assert_response :success
    assert_equal "Store #{assigns(:viewing_tags).collect { |t| ' > ' + t.name}}", assigns(:title)
    assert assigns(:products)
    assert_template 'index'
  end

  # Now call it again with a tag and a subtag.
  def test_show_by_tags_with_subtag
    a_tag = tags(:weapons)
    a_subtag = tags(:mass_destruction)
    get :show_by_tags, :tags => [a_tag.name, a_subtag.name]
    assert_response :success
    assert_equal "Store #{assigns(:viewing_tags).collect { |t| ' > ' + t.name}}", assigns(:title)
    assert assigns(:products)
    assert_template 'index'
  end

  # Call it again with an invalid tag.    
  def test_show_by_tags_invalid
    get :show_by_tags, :tags => ["invalid"]
    assert_response :missing
  end

  # Call it again with an invalid child tag.
  def test_show_by_tags_invalid_subtag
    a_tag = tags(:weapons)
    get :show_by_tags, :tags => [a_tag.name, "invalid"]
    assert_response :missing
  end


  # Test the display_product.
  def test_should_display_product
    # TODO: If this method is not used anymore, get rid of it.
    @product = items(:lightsaber)
    another_product = items(:uranium_portion)
    
    # Get the result of one product that have images.
    get :display_product, :id => @product.id
    # Get the result of one product that don't have images.
    get :display_product, :id => another_product.id
  end
  
  
  # Test the show action.
  def test_show
    @product = items(:lightsaber)
    
    # TODO: A code is being passed to a hash parameter called id.
    get :show, :id => @product.code
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:product)
    assert_equal @product.name, assigns(:title)
    assert_equal 3, assigns(:variations).size
  end

  def test_show_invalid_product
    get :show, :id => "invalid"
    assert_redirected_to :action => :index
    assert !flash[:notice].blank?
  end
  
  def setup_inventory_control
    @product = items(:uranium_portion)
    assert @product.update_attribute('quantity', 0)
    assert_equal 0, @product.reload.quantity
  end
  
  # If inventory control is disabled, you should be able to purchase a product if quantity
  # is set to any amount.
  def test_inventory_control_enabled
    setup_inventory_control()
    assert Preference.find_by_name('store_use_inventory_control').update_attribute('value', 1)
    get :show, :id => @product.code
    assert_response :success
    assert_select "h3#out_of_stock"
  end
    
  def test_inventory_control_disabled
    setup_inventory_control()
    assert Preference.find_by_name('store_use_inventory_control').update_attribute('value', 0)
    get :show, :id => @product.code
    assert_response :success
    assert_select "h3#out_of_stock", false
    assert_select "form#add_to_cart_form"
  end
  
  # Test the show cart action. This is the action that shows the modal cart.
  def test_show_cart
    get :show_cart
    assert_response :success
  end


  # Test the add to cart action.
  # TODO: This action don't work passing variations. 
  # TODO: If this action is not used anymore, get rid of it. 
  def test_add_to_cart_success
    @product = items(:holy_grenade)
    post :add_to_cart, :id => @product.id
    assert_redirected_to :action => :checkout
    cart = assigns(:order)
    assert_equal 1, cart.items.length
  end
  
  def test_add_to_cart_fail
    # Setup
    @product = items(:holy_grenade)
    @product.destroy
    # Exercise
    post :add_to_cart, :id => @product.id
    # Verify
    assert_redirected_to :action => :index
    assert !flash[:notice].blank?
  end


  # Test the add to cart ajax action.
  def test_should_add_to_cart_ajax
    # TODO: This method isn't respecting the inventory control option.
    # Try adding a product.
    @product = items(:towel)
    xhr(:post, :add_to_cart_ajax, :id => @product.id)
    # Here nothing is rendered directly, but a SUBMODAL.show() javascript function is executed.
    cart = assigns(:order)
    assert_equal 1, cart.items.length

    # Try adding a variation.
    a_variation = items(:red_lightsaber)
    xhr(:post, :add_to_cart_ajax, :variation => a_variation.id, :quantity => "2")
    # Here nothing is rendered directly, but a SUBMODAL.show() javascript function is executed.
    cart = assigns(:order)
    assert_equal 2, cart.items.length

    # Try adding another product (that should not be available).
    @product = items(:holy_grenade)
    xhr(:post, :add_to_cart_ajax, :id => @product.id, :quantity => "2")
    assert_response 400
    # Here nothing is rendered directly, but a SUBMODAL.show() javascript function is executed.
    cart = assigns(:order)
    # It should not have added anything.
    assert_equal 2, cart.items.length
    
    # Try adding a product with a non-numerical quantity
    @product = items(:towel)
    xhr(:post, :add_to_cart_ajax, :id => @product.id, :quantity => "a")
    cart = assigns(:order)
    assert_equal 2, cart.items.length
  end
  
  def test_add_to_cart_inventory_control
    product = items(:uranium_portion)
    assert product.update_attribute('quantity', 0)
    assert_equal 0, product.reload.quantity

    # Inventory control enabled
    assert Preference.find_by_name('store_use_inventory_control').update_attribute('value', 1)
    xhr(:post, :add_to_cart_ajax, :id => product.id, :quantity => "1")
    cart = assigns(:order)
    assert_equal 0, cart.items.length
    
    # Inventory control DISABLED
    assert Preference.find_by_name('store_use_inventory_control').update_attribute('value', 0)
    xhr(:post, :add_to_cart_ajax, :id => product.id, :quantity => "1")
    cart = assigns(:order)
    assert_equal 1, cart.items.length
  end
  
  
  # Test the remove from cart ajax action.
  def test_should_remove_from_cart_ajax
    # Try adding a product.
    @product = items(:towel)
    xhr(:post, :add_to_cart_ajax, :id => @product.id)
    # Here nothing is rendered directly, but a SUBMODAL.show() javascript function is executed.
    cart = assigns(:order)
    assert_equal 1, cart.items.length

    # Try removing a product.
    xhr(:post, :remove_from_cart_ajax, :id => @product.id)
    # Here nothing is rendered directly, but a window.location.reload() javascript function is executed.
    cart = assigns(:order)
    assert_equal 0, cart.items.length
    
    # Try removing an invalid product.
    # Make sure this id don't exist.
    @product.destroy
    xhr(:post, :remove_from_cart_ajax, :id => @product.id)
    # Here a text is rendered.
  end


  # Test the empty cart ajax action.
  def test_should_empty_cart_ajax
    # Try adding a product.
    @product = items(:towel)
    xhr(:post, :add_to_cart_ajax, :id => @product.id)
    # Here nothing is rendered directly, but a SUBMODAL.show() javascript function is executed.
    cart = assigns(:order)
    assert_equal 1, cart.items.length

    xhr(:post, :empty_cart_ajax)
    # Here nothing is rendered directly, but a window.location.reload() javascript function is executed.

    assert_equal 0, assigns(:order).items.length
    assert_nil session[:order_id]
  end


  # Test the empty cart action.
  def test_should_empty_cart
    # Try adding a product.
    @product = items(:towel)
    xhr(:post, :add_to_cart_ajax, :id => @product.id)
    # Here nothing is rendered directly, but a SUBMODAL.show() javascript function is executed.
    cart = assigns(:order)
    assert_equal 1, cart.items.length

    post :empty_cart
    assert_redirected_to :action => :index

    assert_equal 0, assigns(:order).items.length
    assert_nil session[:order_id]
  end


  # Test the empty cart action.
  def test_should_empty_cart_after_checkout
    test_checkout_success()
    
    an_order_id = session[:order_id]
    
    post :empty_cart
    assert_redirected_to :action => :index

    assert_equal 0, assigns(:order).items.length
    assert_nil session[:order_id]
    
    # Assert the order was destroyed.
    assert_raise(ActiveRecord::RecordNotFound) {
      Order.find(an_order_id)
    }
  end
  
  def test_checkout_error_layout
    # Add a product to the cart.
    @product = items(:towel)
    xhr(:post, :add_to_cart_ajax, :id => @product.id)
    # Here nothing is rendered directly, but a SUBMODAL.show() javascript function is executed.
    cart = assigns(:order)
    assert_equal 1, cart.items.length

    post(
      :checkout,
      :order_account => {
        :cc_number => "",
        :expiration_year => "",
        :expiration_month => ""
      },
      :shipping_address => {
        :city => "",
        :zip => "",
        :country_id => countries(:US).id,
        :first_name => "",
        :telephone => "",
        :last_name => "",
        :address => "",
        :state => ""
      },
      :billing_address => @scrooge_address.attributes,
      :order_user => {
        :email_address => ""
      }
    )
    assert_response :success
    assert_template 'checkout'
    assert_layout 'checkout'
    assert flash[:notice].include?('There were some problems with the information you entered')
  end
  
  
  # Test the checkout action.
  def test_get_checkout
    test_add_to_cart_success()
    
    get :checkout
    assert_response :success
    assert_template 'checkout'
    assert_layout 'checkout'
    assert_equal "Please enter your information to continue this purchase.", assigns(:title)
    assert_not_nil assigns(:cc_processor)
  end
    
  def test_checkout_fail
    test_add_to_cart_success()
    
    post(
      :checkout,
      :order_account => {
        :cc_number => "",
        :expiration_year => 4.years.from_now.year,
        :expiration_month => "1"
      },
      :shipping_address => {
        :city => "",
        :zip => "",
        :country_id => countries(:US).id,
        :first_name => "",
        :telephone => "",
        :last_name => "",
        :address => "",
        :state => ""
      },
      :billing_address => @scrooge_address.attributes,
      :order_user => {
        :email_address => "uncle.scrooge@whoknowswhere.com"
      }
    )
    assert flash[:notice].include?("There were some problems")
    assert_response :success
  end

  
  def test_checkout_success
    test_add_to_cart_success()
    
    # Post it again with the order already saved.
    post :checkout,
    :order_account => {
      :cc_number => "4007000000027",
      :expiration_year => 4.years.from_now.year,
      :expiration_month => "1"
    },
    :shipping_address => @scrooge_address.attributes,
    :billing_address => @scrooge_address.attributes,
    :order_user => {
      :email_address => "uncle.scrooge@whoknowswhere.com"
    }
    assert flash[:notice].blank?
    assert_redirected_to :action => 'select_shipping_method'
  end
  
  
  # Test the checkout action.
  def test_should_checkout_using_paypal
    # Now we say that we will use paypal ipn.
    assert Preference.save_settings({ "cc_processor" => "PayPal IPN" })

    # Add a product to the cart.
    @product = items(:towel)
    xhr(:post, :add_to_cart_ajax, :id => @product.id)
    # Here nothing is rendered directly, but a SUBMODAL.show() javascript function is executed.
    cart = assigns(:order)
    assert_equal 1, cart.items.length

    get :checkout
    assert_response :success
    assert_template 'checkout'
    assert_equal "Please enter your information to continue this purchase.", assigns(:title)
    assert_not_nil assigns(:cc_processor)
    
    # Post to it an order.
    post :checkout,
    :shipping_address => {
      :city => "",
      :zip => "",
      :country_id => countries(:US).id,
      :first_name => "",
      :telephone => "",
      :last_name => "",
      :address => "",
      :state => ""
    },
    :billing_address => @scrooge_address.attributes,
    :order_user => {
      :email_address => "uncle.scrooge@whoknowswhere.com"
    }
    
    assert_redirected_to :action => :select_shipping_method
  end
  
  
  # Test the checkout action.
  def test_should_checkout_when_logged_as_customer
    login_as_customer :uncle_scrooge
    
    # Add a product to the cart.
    @product = items(:towel)
    xhr(:post, :add_to_cart_ajax, :id => @product.id)
    # Here nothing is rendered directly, but a SUBMODAL.show() javascript function is executed.
    cart = assigns(:order)
    assert_equal 1, cart.items.length

    get :checkout
    assert_response :success
    assert_template 'checkout'
    assert_equal "Please enter your information to continue this purchase.", assigns(:title)
    assert_not_nil assigns(:cc_processor)
    
    # Post to it an order.
    post :checkout,
    :order_account => {
      :cc_number => "4007000000027",
      :expiration_year => 4.years.from_now.year,
      :expiration_month => "1"
    },
    :shipping_address => @santa_address.attributes,
    :billing_address => @scrooge_address.attributes,
    :order_user => {
      :email_address => "uncle.scrooge@whoknowswhere.com"
    },
    :use_separate_shipping_address => "true"
    
    assert_redirected_to :action => :select_shipping_method


    get :checkout
    assert_response :success
    assert_template 'checkout'
    assert_equal "Please enter your information to continue this purchase.", assigns(:title)
    assert_not_nil assigns(:cc_processor)
    
    # Post it again with the order already saved.
    post :checkout,
    :order_account => {
      :cc_number => "4007000000027",
      :expiration_year => 4.years.from_now.year,
      :expiration_month => "1"
    },
    :shipping_address => @santa_address.attributes,
    :billing_address => @scrooge_address.attributes,
    :order_user => {
      :email_address => "uncle.scrooge@whoknowswhere.com"
    },
    :use_separate_shipping_address => "true"
  end
  
  
  # Test the checkout action.
  def test_should_checkout_and_break
    # Add a product to the cart.
    @product = items(:towel)
    xhr(:post, :add_to_cart_ajax, :id => @product.id)
    # Here nothing is rendered directly, but a SUBMODAL.show() javascript function is executed.
    cart = assigns(:order)
    assert_equal 1, cart.items.length

    get :checkout
    assert_response :success
    assert_template 'checkout'
    assert_equal "Please enter your information to continue this purchase.", assigns(:title)
    assert_not_nil assigns(:cc_processor)
    
    # Post to it an order.
    # Not filling out info should cause an error to be raised.
    post :checkout,
    :order_account => {
      :cc_number => "",
      :expiration_year => Time.now.year-1,
      :expiration_month => "1"
    },
    :shipping_address => {
      :city => "",
      :zip => "",
      :country_id => countries(:US).id,
      :first_name => "",
      :telephone => "",
      :last_name => "",
      :address => "",
      :state => ""
    },
    :billing_address => {
      :city => "",
      :zip => "",
      :country_id => countries(:US).id,
      :first_name => "",
      :telephone => "",
      :last_name => "",
      :address => "",
      :state => ""
    },
    :order_user => {
      :email_address => "uncle.scrooge@whoknowswhere.com"
    }
    
    assert_response :success
    assert_template 'checkout'
    assert flash[:notice].include?('There were some problems with the information you entered')
  end
  
  def test_cant_checkout_with_empty_cart
    # Go to the store, no items in cart
    get :index
    order = assigns(:order)
    assert order.empty?
    
    # Try to checkout
    get :checkout
    assert_redirected_to :action => :index
    assert !flash[:notice].blank?
  end
  
  
  # Test the checkout action.
  def test_should_checkout_with_unavailable_products
    # Add full quantity of an item to the cart.
    @product = items(:towel)
    xhr(:post, :add_to_cart_ajax, :id => @product.id, :quantity => @product.quantity)
    assert_response :success
    assert_equal 1, assigns(:order).items.length

    # Emulate another customer purchasing items before we checkout
    @product.update_attribute(:quantity, 1)

    get :checkout
    assert_response :success
    assert_template 'checkout'
    assert_equal "Please enter your information to continue this purchase.", assigns(:title)
    assert_not_nil assigns(:cc_processor)
    
    # Post to it an order.
    post :checkout,
    :order_account => {
      :cc_number => "4007000000027",
      :expiration_year => 4.years.from_now.year,
      :expiration_month => "1"
    },
    :shipping_address => {
      :city => "",
      :zip => "",
      :country_id => countries(:US).id,
      :first_name => "",
      :telephone => "",
      :last_name => "",
      :address => "",
      :state => ""
    },
    :billing_address => @scrooge_address.attributes,
    :order_user => {
      :email_address => "uncle.scrooge@whoknowswhere.com"
    }
    
    assert_redirected_to :action => :index
    assert flash[:notice].include?("have gone out of stock before you could purchase them")
  end
  
  # Test the select shipping method action.
  def test_should_select_shipping_method
    test_checkout_success()

    get :select_shipping_method
    assert_response :success
    assert_template 'select_shipping_method'
    assert_equal "Select Your Shipping Method - Step 2 of 3", assigns(:title)
    assert_not_nil assigns(:default_price)
  end
  
  
  # Test the select shipping method action.
  def test_should_select_shipping_method_without_an_order
    get :select_shipping_method
    assert_redirected_to :action => :index
  end  
  

  # Test the view shipping method action.
  def test_should_view_shipping_method
    # TODO: If this action is not used anymore, get rid of it. 
    get :view_shipping_method
    assert_response 302
  end
  
  
  # Test the set shipping method action.
  def test_should_set_shipping_method_with_confirmation
    # Execute an earlier test as this one deppends on it.
    test_should_select_shipping_method

    # Post to it when the show confirmation preference is true.
    assert Preference.save_settings({ "store_show_confirmation" => "1" })
    post :set_shipping_method, :ship_type_id => order_shipping_types(:ups_ground).id
    assert_redirected_to :action => :confirm_order
  end


  # Test the set shipping method action.
  def test_should_set_shipping_method_without_confirmation
    # Execute an earlier test as this one deppends on it.
    test_should_select_shipping_method

    # Post to it when the show confirmation preference is false.
    assert Preference.save_settings({ "store_show_confirmation" => "0" })
    post :set_shipping_method, :ship_type_id => order_shipping_types(:ups_ground).id
    assert_redirected_to :action => :finish_order
  end

  # Test the confirm order action.
  def test_should_confirm_order
    # Execute an earlier test as this one deppends on it.
    #    test_should_select_shipping_method

    # TODO: The code have an unreachable part, the order_shipping_type_id will never be nil because
    # the database schema don't let it.
    #   assert_equal assigns(:order).order_shipping_type_id, nil
    
    # Get the confirm order action when the shipping is nil.
 #   get :confirm_order
 #   assert_redirected_to :action => :select_shipping_method
  end


  # Test the finish order action.
  def test_should_finish_order_with_authorize
    # Execute an earlier test as this one deppends on it.
    test_should_set_shipping_method_without_confirmation
   
    order = Order.find(session[:order_id])

    # Now we say that we will use authorize. Mock the method.
    assert Preference.save_settings({ "cc_processor" => "Authorize.net" })
    Order.any_instance.expects(:run_transaction_authorize).once.returns(true)
    
    # Save initial quantity
    oli = assigns(:order).order_line_items.first
    initial_quantity = oli.item.quantity

    # Post to the finish order action.
    post :finish_order
    assert_response :success
    assert_select "p", :text => /Card processed successfully/
    
    # Ensure items still in order
    assert !order.empty?, "Order items were emptied when they shouldn't be."
    
    # Ensure customer has been logged in, so they may download their files
    assert_not_nil session[:customer], "Customer was not logged in after successful purchase."
  end


  # Test the finish order action.
  def test_should_finish_order_with_authorize_with_error
    # Execute an earlier test as this one deppends on it.
    test_should_set_shipping_method_without_confirmation
   
    # Now we say that we will use authorize. Mock the method.
    assert Preference.save_settings({ "cc_processor" => "Authorize.net" })
    Order.any_instance.expects(:run_transaction_authorize).once.returns(false)

    # Save initial quantity
    an_order_line_item = assigns(:order).order_line_items.first
    initial_quantity = an_order_line_item.item.quantity

    # Post to the finish order action.
    post :finish_order
    assert_redirected_to :action => :checkout
    assert flash[:notice].include?("Sorry, but your transaction")

    # Quantity should NOT be updated.
    an_order_line_item.item.reload
    assert_equal initial_quantity, an_order_line_item.item.quantity
  end
  
  # Test the finish order action.
  def test_should_finish_order_with_paypal
    # Execute an earlier test as this one deppends on it.
    test_should_set_shipping_method_without_confirmation
   
    order = Order.find(session[:order_id])

    # Now we say that we will use paypal ipn. Mock the method.
    assert Preference.save_settings({ "cc_processor" => "PayPal IPN" })
    Order.any_instance.expects(:run_transaction_paypal_ipn).once.returns(5)

    # Save initial quantity
    oli = assigns(:order).order_line_items.first
    initial_quantity = oli.item.quantity

    # Post to the finish order action.
    post :finish_order
    assert_response :success
    assert_select "p", :text => /Transaction processed successfully/
    
    # Ensure items still in order
    assert !order.empty?, "Order items were emptied when they shouldn't be."
    
    assert_not_nil session[:customer], "Customer was not logged in after successful purchase."
  end


  # Test the finish order action.
  def test_should_finish_order_with_paypal_without_ipn_confirmation
    # Execute an earlier test as this one deppends on it.
    test_should_set_shipping_method_without_confirmation
   
    # Now we say that we will use paypal ipn. Mock the method.
    assert Preference.save_settings({ "cc_processor" => "PayPal IPN" })
    Order.any_instance.expects(:run_transaction_paypal_ipn).once.returns(4)

    # Save initial quantity
    an_order_line_item = assigns(:order).order_line_items.first
    initial_quantity = an_order_line_item.item.quantity

    # Post to the finish order action.
    post :finish_order
    assert_response :success
    assert_select "p", :text => /have not heard back from them yet/

    # Quantity should NOT be updated.
    an_order_line_item.item.reload
    assert_equal initial_quantity, an_order_line_item.item.quantity
  end
  
  
  # Test the finish order action.
  def test_should_finish_order_with_paypal_with_error
    # Execute an earlier test as this one deppends on it.
    test_should_set_shipping_method_without_confirmation
   
    # Now we say that we will use paypal ipn. Mock the method.
    assert Preference.save_settings({ "cc_processor" => "PayPal IPN" })
    Order.any_instance.expects(:run_transaction_paypal_ipn).once.returns(3)

    # Save initial quantity
    an_order_line_item = assigns(:order).order_line_items.first
    initial_quantity = an_order_line_item.item.quantity

    # Post to the finish order action.
    post :finish_order
    assert_redirected_to :action => :checkout
    assert flash[:notice].include?("Something went wrong and your transaction failed")

    # Quantity should NOT be updated.
    an_order_line_item.item.reload
    assert_equal initial_quantity, an_order_line_item.item.quantity
  end

end