require File.dirname(__FILE__) + '/../test_helper'

class CustomersControllerTest < ActionController::TestCase
  fixtures :order_users, :orders, :wishlist_items, :items

  def setup
    @customer = order_users(:santa)
  end

  def test_login
    get :login
    assert_response :success
    assert_equal assigns(:title), "Customer Login"
    assert_template 'login'
  end
    
  def test_login_success
    post :login, :login => @customer.email_address, :password => @customer.password
    # If loged in we should be redirected to orders. 
    assert_response :redirect
    assert_redirected_to :action => :orders
    assert_equal session[:customer], @customer.id
  end

  def test_login_fail
    post :login, :login => @customer.email_address, :password => "wrong_password"
    assert_response :success
    assert_template 'login'
    assert_equal 'Login unsuccessful', flash[:notice]
    assert_equal session[:customer], nil
  end
  
  def test_login_modal_get
    # Call it again asking for a modal response.
    get :login, :modal => "true"
    assert_response :success
    assert_template 'login'
  end
    
  def test_login_modal_post
    post :login, :modal => "true", :login => @customer.email_address, :password => @customer.password
    assert_response :success
    assert_template 'shared/modal_refresh'
  end

  # Here we test if we can login and return to a previous action.
  def test_login_and_return
    # Try to access an action that needs login, 
    # the uri should be saved in the session.
    get :account
    post :login, :login => @customer.email_address, :password => @customer.password
    assert_response :redirect
    assert_redirected_to :action => :account
  end

  def test_logout
    login_as_customer :santa
    # Test the logout here too.
    post :logout
    assert_response :redirect
    assert_redirected_to '/'
    assert_equal session[:customer], nil
  end

  def test_new
    get :new
    assert_response :success
    assert_equal assigns(:title), "New Account"
    assert_template 'new'
  end
    
  def test_new_success
    post :new,
    :customer => {
      :email_address => "customer@nowhere.com",
      :password => "password"
    }
    
    assert_response :redirect
    assert_redirected_to :action => :wishlist
    
    # Verify that the customer really is there.
    @customer = OrderUser.find_by_email_address('customer@nowhere.com')
    assert_not_nil @customer

    # Assert the customer id is in the session.
    assert_equal session[:customer], @customer.id
  end

  def test_new_fail
    post :new,
    :customer => {
      :email_address => "customer",
      :password => "password"
    }    
    # If not saved, the same page will be rendered again with error explanations.
    assert_response :success
    assert_template 'new'
    # Here we assert that a flash message appeared and the proper fields was marked.
    assert_select "p", :text => /There was a problem creating your account./
    assert_select "div.fieldWithErrors input#customer_email_address"
  end


  def test_account
    login_as_customer :santa
    
    # Call the edit form.
    get :account
    assert_response :success
    assert_equal assigns(:title), "Your Account Details"
    assert_template 'account'
  end

  def test_account_update_success
    login_as_customer :santa
    
    new_email_address = "#{@customer.email_address}.changed"
    
    # Post to it the current customer changed.
    post :account,
    :customer => {
      :email_address => new_email_address,
      :password => "#{@customer.password}"
    }
    
    assert_response :success
    assert_template 'account'
    assert_select "p", :text => /Account details saved./
    @customer.reload
    assert_equal @customer.email_address, new_email_address
  end


  def test_account_update_fail
    login_as_customer :santa

    old_email_address = @customer.email_address    
    # Post to it the current customer changed.
    post :account,
    :customer => {
      :email_address => "invalid",
      :password => "#{@customer.password}"
    }
    assert_response :success
    assert_template 'account'
    assert_select "p", :text => /There was a problem saving your account./
    assert_select "div.fieldWithErrors input#customer_email_address"
    @customer.reload
    assert_equal @customer.email_address, old_email_address
  end


  def test_reset_password
    get :reset_password
    assert_response :success
    assert_equal assigns(:title), "Reset Password"
    assert_template 'reset_password'
  end
  
  def test_reset_password_modal
    # Call again the reset_password form in a modal state.
    get :reset_password, :modal => "true"
    assert_response :success
    assert_equal assigns(:title), "Reset Password"
    assert_template 'reset_password'
  end


  # Reset the password from a customer.
  def test_reset_password_success
    # Setup the mailer.
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    old_password = @customer.password
    
    # Post to it the current customer changed.
    assert_difference "ActionMailer::Base.deliveries.length" do
      post :reset_password,
        :modal => "",
        :login => @customer.email_address
    end
    
    # If done should redirect to login. 
    assert_response :redirect
    assert_redirected_to :action => :login, :modal => '', :login => @customer.email_address

    # We need to follow the redirect.
    assert_equal "Your password has been reset and emailed to you.", flash[:notice]
    
    # Verify that the change was made.
    @customer.reload
    assert_not_equal @customer.password, old_password
  end

  # Don't reset the password from a customer.
  def test_reset_password_fail
    # Setup the mailer.
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    # Post to it the current customer changed.
    assert_no_difference "ActionMailer::Base.deliveries.length" do
      post :reset_password,
        :modal => "",
        :login => "invalid"
    end
    assert_response :success
    assert_template 'reset_password'

    # Here we assert that a flash message appeared.
    assert_select "p", :text => /That account wasn/
  end

  def test_orders
    login_as_customer :santa

    get :orders
    assert_response :success
    assert_equal assigns(:title), "Your Orders"
    assert_template 'orders'
    assert_not_nil assigns(:orders)
    
    # Assert all orders are being shown.
    assert_select "h1", :text => /Your Orders/
    order_numbers_array = @customer.orders.collect {|p| p.order_number}
    order_numbers_array.each do |item|
      assert_select "td", :text => item
    end
  end

  def test_wishlist
    login_as_customer :santa

    get :wishlist
    assert_response :success
    assert_equal assigns(:title), "Your Wishlist"
    assert_template 'wishlist'
    assert_not_nil assigns(:items)
    
    # Assert all items of the wishlist are being shown.
    assert_select "h1", :text => /Your Wishlist/
    wishlist_items_array = @customer.items.collect {|p| p.name}
    wishlist_items_array.each do |item|
      assert_select "a", :text => item
    end
  end
  
  
  def test_add_to_wishlist
    login_as_customer :santa
    assert @customer.wishlist_items.destroy_all

    assert_difference '@customer.wishlist_items.count' do
      post :add_to_wishlist, :id => items(:towel).id
    end
    
    # Verify
    assert_response :redirect
    assert_redirected_to :action => :wishlist
    wishlist_items_array = @customer.items.collect {|p| p.name}
  end


  # Test that an invalid item will not be added to the wishlist.
  def test_add_to_wishlist_fail
    login_as_customer :santa
    assert @customer.wishlist_items.destroy_all

    assert_no_difference '@customer.wishlist_items.count' do
      post :add_to_wishlist, :id =>  'fake_product_id'
    end
    
    # Even on error should redirect to wishlist. 
    assert_response :redirect
    assert_redirected_to :action => :wishlist
    assert flash[:notice].include?('find the item that you wanted to add to your wishlist. Please try again.')
  end

  def test_add_to_wishlist_fail_no_id
    login_as_customer :santa
    assert @customer.wishlist_items.destroy_all
    
    # Now without an item id.
    assert_no_difference '@customer.wishlist_items.count' do
      post :add_to_wishlist
    end
    
    # Even on error should redirect to wishlist. 
    assert_response :redirect
    assert_redirected_to :action => :wishlist
    assert flash[:notice].include?('specify an item to add to your wishlist...')
  end


  # Test if we can remove wishlist items using ajax calls.
  def test_remove_wishlist_item
    login_as_customer :santa

    p = items(:uranium_portion)

    get :wishlist
    assert_response :success
    assert_equal assigns(:title), "Your Wishlist"
    assert_template 'wishlist'
    assert_not_nil assigns(:items)
    
    # Initially we should have two items.
    assert_select "div.padLeft" do
      assert_select "div.product", :count => 2
    end

    # Items should be erased using ajax calls.
    xhr(:post, :remove_wishlist_item, :id => p.id)

    # At this point, the call doesn't issue a rjs statement, the field is just
    # hidden and the controller method executed, in the end the item should
    # not be in the database.

    assert_equal @customer.items.length, 1
  end


  # Test if the email address can be checked.
  def test_check_email_address
    # TODO: This should be trigered in checkout when the field is being filled.

    # The email address should be checked using ajax calls.
    xhr(:post, :check_email_address, :email_address => @customer.email_address)

    # Here an insertion rjs statement is not generated, a javascript function
    # is just spited out to be executed.
    # puts @response.body

    # Post again with an invalid address.
    xhr(:post, :check_email_address, :email_address => "invalid")
  end

  def test_download_success
    login_as_customer :santa
    o = orders(:santa_next_christmas_order)
    # Download file
    get :download_for_order, 
      :order_number => o.order_number, 
      :download_id => o.downloads.first.id
    assert_response :success, "File wasn't downloaded after purchase."
  end
    
  def test_download_fail_order_number
    login_as_customer :santa
    o = orders(:santa_next_christmas_order)
    get :download_for_order, 
      :order_number => 12345789, 
      :download_id => o.downloads.first.id
    assert_response :missing, "File was downloaded when it shouldn't have been."
  end

  def test_download_fail_download_id
    login_as_customer :santa
    o = orders(:santa_next_christmas_order)    
    # Try to download with wrong download id
    get :download_for_order, 
      :order_number => o.order_number, 
      :download_id => 1234567
    assert_response :missing, "File was downloaded when it shouldn't have been."
  end

end
