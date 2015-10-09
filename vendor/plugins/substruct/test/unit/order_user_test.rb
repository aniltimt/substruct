require File.dirname(__FILE__) + '/../test_helper'

class OrderUserTest < ActiveSupport::TestCase
  fixtures :order_users, :orders, :items
  
  def setup
    @santa = order_users(:santa)
    @mustard = order_users(:mustard)
    @new_customer = OrderUser.new(
      :email_address => "arthur.dent@whoknowswhere.com",
      :password => "",
      :first_name => "",
      :last_name => ""
    )
  end

  # Test if a valid order user can be created with success.
  def test_create_order_user
    @new_customer.password = 'password'
    assert @new_customer.save
  end

  # Test if a valid order user can be created with success and a password will be
  # generated if nil.
  def test_create_order_user_and_generate_password
    assert @new_customer.password.blank?
    assert @new_customer.save
    assert !OrderUser.find_by_email_address(@new_customer.email_address).password.empty?
  end
  
  # Test if an order user can be found with success.
  def test_find_order_user
    assert_nothing_raised {
      OrderUser.find(@santa.id)
    }
  end

  def test_get_csv_for
    csv_string = OrderUser.get_csv_for(OrderUser.find(:all))
    assert_kind_of String, csv_string
  end

  # Test if an order user can be updated with success.
  def test_update_order_user
    assert @santa.update_attributes(
      :email_address => 'santa@whoknowswhere.com'
    )
  end

  def test_invalid_email_address_blank
    @new_customer.email_address = ''
    assert !@new_customer.valid?
    assert @new_customer.errors.invalid?(:email_address)
    assert_same_elements ["Please fill in this field.", "Please enter a valid email address."], @new_customer.errors.on(:email_address)
  end

  def test_invalid_email_address_format
    @new_customer.email_address = "arthur.dent"
    assert !@new_customer.valid?
    assert @new_customer.errors.invalid?(:email_address)
    assert_equal "Please enter a valid email address.", @new_customer.errors.on(:email_address)
  end

  # An order user must have an unique email address.
  def test_invalid_email_address_unique
    @new_customer.email_address = "santa.claus@whoknowswhere.com"
    Preference.save_setting 'store_require_login' => 1
    assert !@new_customer.valid?
    assert @new_customer.errors.invalid?(:email_address)
    assert_equal "\n\t    This email address has already been taken in our system.<br/>\n\t    If you have already ordered with us, please login.\n\t  ", @new_customer.errors.on(:email_address)
  end

  # Test if an order user can be authenticated.
  def test_authenticate_order_user
    assert_equal @santa, OrderUser.authenticate("santa.claus@whoknowswhere.com", "santa")
    assert_equal @santa, OrderUser.authenticate("santa.claus@whoknowswhere.com", @santa.last_order.order_number)
    assert OrderUser.authenticate?("santa.claus@whoknowswhere.com", "santa")
  end
  
  
  # Test if an order user with a wrong password will NOT be authenticated.
  def test_not_authenticate_order_user
    assert_equal nil, OrderUser.authenticate("santa.claus@whoknowswhere.com", "wrongpassword")
    assert !OrderUser.authenticate?("santa.claus@whoknowswhere.com", "wrongpassword")
  end
  
  def test_name
    assert_kind_of OrderAddress, @santa.last_billing_address
    assert_equal @santa.last_billing_address.name, @santa.name
    
    assert @santa.last_billing_address.destroy
    assert_nil @santa.reload.last_billing_address
    
    assert_equal "[No name given]", @santa.name
  end
  
  
  # Test if we can find the last billing address.
  def test_last_billing_address
    assert_equal @santa.last_order.billing_address, @santa.last_billing_address
    assert_equal @santa.billing_address, @santa.last_billing_address

    another_order_user = order_users(:mustard)
    assert_equal nil, another_order_user.last_billing_address
    assert_equal @santa.billing_address, @santa.last_billing_address
  end
  
  
  # Test if we can find the last shipping address.
  def test_last_shipping_address
    assert_equal @santa.last_order.shipping_address, @santa.last_shipping_address
    assert_equal @santa.shipping_address, @santa.last_shipping_address

    another_order_user = order_users(:mustard)
    assert_equal nil, another_order_user.last_shipping_address
    assert_equal @santa.shipping_address, @santa.last_shipping_address
  end


  # Test if we can find the last order account #
  def test_last_order_account
    assert_equal @santa.last_order.order_account, @santa.last_order_account
    assert_equal @santa.order_account, @santa.last_order_account

    another_order_user = order_users(:mustard)
    assert_equal nil, another_order_user.last_order_account
    assert_equal @santa.order_account, @santa.last_order_account
  end


  # Test if the password can be reseted.
  def test_reset_password
    # Setup the mailer.
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    initial_mbox_length = ActionMailer::Base.deliveries.length

    old_password = @santa.password
    
    @santa.reset_password
    new_password = @santa.password

    assert_equal new_password.length, 8
    assert_not_equal old_password, new_password
    
    # We should have received a mail about that.
    assert_equal ActionMailer::Base.deliveries.length, initial_mbox_length + 1
  end
  
  
  # TODO: Theres no need to have these methods.
  # Test if we can add and remove items from wishlist.
  def test_add_and_remove_items_from_wishlist
    # Load an user and some products.
    a_towel = items(:towel)
    a_stuff = items(:the_stuff)

    assert_equal @mustard.items.count, 0
    @mustard.add_item_to_wishlist(a_towel)
    @mustard.add_item_to_wishlist(a_stuff)
    assert_equal @mustard.items.count, 2
    @mustard.remove_item_from_wishlist(a_towel)
    @mustard.remove_item_from_wishlist(a_stuff)
    assert_equal @mustard.items.count, 0

    # Try to remove an item that isnt there anymore.
    assert !@mustard.remove_item_from_wishlist(a_stuff)
end
  
  
end
