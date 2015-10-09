require File.dirname(__FILE__) + '/../test_helper'

class OrderTest < ActiveSupport::TestCase
  fixtures(
    :affiliates,
    :orders, :order_status_codes, :order_users, :order_accounts, 
    :order_shipping_types, :order_shipping_weights,
    :order_line_items, :order_addresses, 
    :items, :countries, :promotions, :preferences
  )
  
  def setup
    @order = orders(:santa_next_christmas_order)
  end
  
  def setup_new_order
    @o = Order.new(
      :tax => 0.0,
      :product_cost => 1.25,
      :created_on => 1.day.ago,
      :shipping_address => order_addresses(:uncle_scrooge_address),
      :order_user => order_users(:uncle_scrooge),
      :billing_address => order_addresses(:uncle_scrooge_address),
      :order_shipping_type => order_shipping_types(:ups_xp_critical),
      :promotion_id => 0,
      :shipping_cost => 30.0,
      :order_number => Order.generate_order_number,
      :order_account => order_accounts(:uncle_scrooge_account),
      :order_status_code => order_status_codes(:ordered_paid_to_ship)
    )
    @li = OrderLineItem.for_product(items(:small_stuff))
    @li_2 = OrderLineItem.for_product(items(:grey_coat))
    
    # Save the total value before set any promotion.
    @totals = {
      :order => @o.total,
      :line_items => @o.line_items_total
    }
  end
  
  def setup_new_order_with_items
    setup_new_order()
    @o.order_line_items << @li
    @o.order_line_items << @li_2
    assert @o.save
    # Save the total value before set any promotion.
    @totals = {
      :order => @o.total,
      :line_items => @o.line_items_total
    }
  end
  
  def test_associations
    assert_working_associations
    assert_not_nil @order.customer
  end

  def test_can_save_cart_order
    order = Order.create
    assert !order.new_record?
    cart_status_code = OrderStatusCode.find_by_name('CART')
    assert_equal order.order_status_code, cart_status_code, "Order wasn't initialized to CART status code."
  end

  # Test if a valid order can be created with success.
  def test_create_order
    setup_new_order()
    @o.order_line_items << OrderLineItem.for_product(items(:small_stuff))
    assert @o.save
  end

  # Test if an order can be found with success.
  def test_find_order
    assert_nothing_raised {
      Order.find(@order.id)
    }
  end
  
  def test_destroy_old_carts
    # Make an old, empty CART item
    old_cart = Order.new(
      :order_status_code => order_status_codes(:cart),
      :product_cost => 0,
      :created_on => Time.now - 1.day
    )
    assert old_cart.save
    old_cart_id = old_cart.reload.id
    assert_difference "Order.count", -1 do
      Order.destroy_old_carts
    end
    assert_nil Order.find_by_id(old_cart_id)
  end


  # Test if an invalid order really will NOT be created.
  def dont_test_not_create_invalid_order
#    # TODO: By now theres no way to make an order invalid, it accepts any blank values and saves it.
#    an_order = Order.new
#    assert !an_order.valid?
#    assert an_order.errors.invalid?(:order_number)
#    # An order must have a number.
#    assert_equal "can't be blank", an_order.errors.on(:order_number)
#    assert !an_order.save
  end


  # Test if the product cost is being set before save.
  def test_set_product_cost
    # Setup
    setup_new_order()
    oli = OrderLineItem.for_product(items(:small_stuff))
    @o.order_line_items << oli
    # Exercise
    assert @o.save
    # Verify
    assert_equal @o.reload.product_cost, oli.total
  end

  # PROMOTIONS ----------------------------------------------------------------
  
  # Test if the line item that represents a promotion is returned if present.
  # FIXME: This method doesn't find the promotion line item if the promotion has an associated item (get 1 free promotions).
  def test_promotion_line_item
    # Setup
    promo = promotions(:percent_rebate)
    setup_new_order_with_items()
    # Exercise
    @o.promotion_code = promo.code
    assert @o.save
    assert_kind_of Promotion, @o.promotion
    # Verify
    assert_equal @o.promotion_line_item.name, promo.description
  end
  
  def test_promotion_code_nil
    setup_new_order()
    assert @o.promotion.nil?
    assert_equal nil, @o.promotion_code
  end
  
  def test_promotion_code_exists
    # Setup
    promo = promotions(:percent_rebate)
    setup_new_order_with_items()
    # Exercise
    @o.promotion_code = promo.code
    assert @o.save
    assert_equal promo.code, @o.promotion_code
  end

  # TODO: oli.item_id = promo.item_id is an ugly hack, 
  #       setting an order item to empty in some situations.
  def test_set_promo_code_fixed_rebate
    # Setup
    setup_new_order_with_items()
    promo = promotions(:fixed_rebate)
    # Exercise
    @o.promotion_code = promo.code
    assert @o.save
    assert_equal promo, @o.promotion
    # Verify
    expected_total = @totals[:order] - promo.discount_amount
    assert_equal(
      expected_total.round(2),
      @o.total, 
      "Fixed rebate verification error."
    )
  end
    
  def test_set_promo_code_percent_rebate
    # Setup
    setup_new_order_with_items()
    promo = promotions(:percent_rebate)
    # Exercise
    @o.promotion_code = promo.code
    assert @o.save
    assert_equal promo, @o.promotion
    # Verify
    expected_total = @totals[:order] - (@totals[:line_items] * (promo.discount_amount/100))
    assert_equal(
      expected_total.round(2),
      @o.total, 
      "Percent rebate verification error."
    )
  end

  # Test a fixed rebate with a minimum cart value
  def test_set_promo_code_fixed_min_value
    # Setup
    setup_new_order_with_items()    
    @promo = promotions(:minimum_rebate)
    assert @totals[:order] >= @promo.minimum_cart_value
    # Exercise
    assert @o.should_promotion_be_applied?(@promo)
    @o.promotion_code = @promo.code
    assert @o.save
    @o.reload
    assert_equal @promo, @o.promotion
    # Verify
    expected_total = @totals[:order] - @promo.discount_amount
    assert_equal(
      expected_total.round(2), 
      @o.total, 
      "Fixed rebate with minimum cart value verification error."
    )
  end
  
  def test_set_promo_code_buy_one_get_one_free
    # Setup
    setup_new_order()
    promo = promotions(:eat_more_stuff)
    @o.order_line_items << @li
    assert @o.save    
    # Save the quantity before set the promotion.
    initial_line_item_quantity = @o.order_line_items.find_by_name(@li.name).quantity
    @o.promotion_code = promo.code
    
    # Exercise
    assert @o.save
    
    # Verify
    assert_equal @o.order_line_items.find_by_name(@li.name).quantity, initial_line_item_quantity
    assert_equal @o.order_line_items.find_by_name(promo.description).quantity, promo.discount_amount
    # order_line_items.name return the item name but order_line_items.find_by_name finds using the line item real name (the promotion description).
    assert_not_equal @o.order_line_items.find_by_name(@li.name), @o.order_line_items.find_by_name(promo.description)
  end

  
  # Promotions applied when order has multiple items should
  # be reverted if the threshold ever drops below minimum value.
  def test_promo_code_minimum_bug
    test_set_promo_code_fixed_min_value()
    # Remove expensive item
    assert @o.order_line_items.delete(@li_2)
    assert @promo.minimum_cart_value > @o.total
    assert @o.save
    # Verify
    @o.reload
    assert_nil @o.promotion
    assert_equal 1, @o.order_line_items.size
    assert @o.order_line_items.include?(@li)
  end
  
  # Ensure that promotions can't offset the order so much
  # that the balance becomes negative.
  def test_promo_code_negative_value_bug
    # Setup  / preverify
    promo = promotions(:fixed_rebate)
    promo_discount = 5000.00
    assert promo.update_attribute(:discount_amount, promo_discount)
    setup_new_order_with_items()
    assert promo.discount_amount > @o.total
    # Exercise
    @o.promotion_code = promo.code
    assert @o.save
    # Verify
    assert @o.total >= 0, "Order total was: #{@o.total}"
  end

  # Test if it will properly delete a previous promotion before apply a new one.
  def test_delete_previous_promotion_line_item
    setup_new_order_with_items()
    
    a_fixed_rebate = promotions(:fixed_rebate)
    @o.promotion_code = a_fixed_rebate.code
    # Saving it, sets the promo code and product cost.
    assert @o.save
    # Assert the promotion is there.
    assert_equal @o.order_line_items.find_by_name(a_fixed_rebate.description).name, a_fixed_rebate.description, "The fixed rebate wasn't added properly."

    # Test a percent rebate.
    a_percent_rebate = promotions(:percent_rebate)
    @o.promotion_code = a_percent_rebate.code
    # Saving it, sets the promo code and product cost.
    assert @o.save
    # Assert the promotion is there.
    assert_equal @o.order_line_items.find_by_name(a_percent_rebate.description).name, a_percent_rebate.description, "The percent rebate wasn't added properly."

    # Assert the previous promotion is NOT there.
    assert_equal @o.order_line_items.find_by_name(a_fixed_rebate.description), nil, "The fixed rebate is still there."
  end
  
  def test_remove_promotion
    setup_new_order_with_items()
    promo = promotions(:fixed_rebate)
    @o.promotion_code = promo.code
    assert @o.save
    assert_kind_of OrderLineItem, @o.promotion_line_item
    # Exercise
    @o.remove_promotion
    # Verify
    @o.reload
    assert_nil @o.promotion
    assert_nil @o.promotion_line_item
  end
  
  # If for some unforseen reason multiple promotion items get added this
  # ensures we remove them all when removing a promotion.
  def test_remove_promotion_multiple_items
    setup_new_order_with_items()
    editable_order_codes = (1..5)
    editable_order_codes.each do |status_id|
      o_status = OrderStatusCode.find(status_id)
      assert_kind_of OrderStatusCode, o_status

      @o.order_status_code = o_status
      assert @o.is_editable?
      
      promo = promotions(:fixed_rebate)
      @o.promotion_code = promo.code
      assert @o.save
      assert_kind_of OrderLineItem, @o.promotion_line_item
      # Add dupe line item.
      dupe_item = @o.promotion_line_item.clone
      @o.order_line_items << dupe_item
      assert_equal 2, @o.order_line_items.count(
        :conditions => ["name = ?", @o.promotion.description]
      )
      # Remove
      @o.remove_promotion()
      assert_nil @o.promotion_line_item
    end
  end
  
  def test_should_promotion_be_applied_expired
    setup_new_order()
    promo = promotions(:old_rebate)
    assert !promo.is_active?
    assert !@o.should_promotion_be_applied?(promo)
  end
  
  def test_should_promotion_be_applied_not_expired
    setup_new_order_with_items()
    promo = promotions(:old_rebate)
    promo.stubs(:is_active?).returns(true)
    assert @o.should_promotion_be_applied?(promo)
  end
  
  def test_should_promotion_be_applied_buy_n_get_free
    setup_new_order()
    promo = promotions(:eat_more_stuff)
    assert_equal @li.item, promo.item
    assert @o.order_line_items.empty?
    # Shouldnt be applied yet. No items on the order
    assert !@o.should_promotion_be_applied?(promo)
    # Add the item to the order
    @o.order_line_items << @li
    # Now it's ok to apply the promotion
    assert @o.should_promotion_be_applied?(promo)
  end
  
  def test_should_promotion_be_applied_min_cart_value
    setup_new_order_with_items()    
    @promo = promotions(:minimum_rebate)
    assert @totals[:order] >= @promo.minimum_cart_value
    # Exercise
    assert @o.should_promotion_be_applied?(@promo)
    @o.order_line_items.delete(@li_2)
    # Verify
    assert !@o.should_promotion_be_applied?(@promo)
  end
  
  # Orders that have been placed & finished will still fire the 
  # cleanup_promotion callback. Need to skip it so promotions
  # don't get accidentally removed later on.
  def test_cleanup_promotion_order_finished
    # Setup - add promotion and complete order
    setup_new_order_with_items()
    promo = promotions(:fixed_rebate)
    @o.promotion_code = promo.code
    @o.order_status_code = order_status_codes(:ordered_paid_to_ship)
    assert @o.save
    
    # Now expire the promo
    assert promo.update_attributes({
      :start => Date.today - 2.weeks,
      :end => Date.today - 1.week
    })
    promo.reload
    @o.reload
    
    # Update something on the order, like an admin would.
    # Maybe we shipped out the order and changed the status code.
    @o.order_status_code = order_status_codes(:sent_to_fulfillment)
    assert !@o.should_promotion_be_applied?(promo)
    assert @o.save
    
    @o.reload
    
    # Check to see if promotion is still applied (it should be!)
    assert_equal promo, @o.promotion
    assert_kind_of OrderLineItem, @o.promotion_line_item
  end
  
  
  def test_cleanup_order_no_items
    setup_new_order_with_items()
    promo = promotions(:fixed_rebate)
    @o.promotion_code = promo.code
    assert @o.save
    # Remove items
    @o.remove_product(@li.item)
    @o.remove_product(@li_2.item)
    # Verify
    @o.reload
    assert_equal 0, @o.order_line_items.count, @o.order_line_items.inspect
    assert_nil @o.promotion
    assert_nil @o.promotion_line_item
  end

  # END PROMOTIONS ------------------------------------------------------------

  
  # Test if orders can found using the search method.
  def test_search_order
    # Test a search.
    assert_same_elements Order.search("Santa"), orders(:santa_next_christmas_order, :an_order_on_cart, :an_order_to_charge, :an_order_on_hold_payment_failed, :an_order_on_hold_awaiting_payment, :an_order_ordered_paid_shipped, :an_order_sent_to_fulfillment, :an_order_cancelled, :an_order_returned)
    # Test with changed case. (it should be case insensitive)
    assert_same_elements Order.search("santa"), orders(:santa_next_christmas_order, :an_order_on_cart, :an_order_to_charge, :an_order_on_hold_payment_failed, :an_order_on_hold_awaiting_payment, :an_order_ordered_paid_shipped, :an_order_sent_to_fulfillment, :an_order_cancelled, :an_order_returned)
    # Test a select count.
    assert_equal Order.search("santa", true), 9
  end


  # Test if orders can found by country using the search method.
  def test_search_order_by_country
    # Test a search.
    assert_same_elements Order.find_by_country(countries(:US).id), orders(:santa_next_christmas_order, :an_order_on_cart, :an_order_to_charge, :an_order_on_hold_payment_failed, :an_order_on_hold_awaiting_payment, :an_order_ordered_paid_shipped, :an_order_sent_to_fulfillment, :an_order_cancelled, :an_order_returned)
    # Test a select count.
    assert_equal Order.find_by_country(countries(:US).id, true), 9
  end

  
  # Test if a random unique number will be generated.
  def test_generate_random_unique_order_number
    sample_number = Order.generate_order_number
    assert_nil Order.find(:first, :conditions => ["order_number = ?", sample_number])
  end
  
  
  # Test if the sales totals for a given year will be generated.
  def test_get_sales_totals_for_year
    sales_totals = Order.get_totals_for_year(2007)
    assert_equal 1, sales_totals[1]['number_of_sales'].to_f
    assert_equal @order.product_cost, sales_totals[1]['sales_total'].to_f
    assert_equal @order.tax, sales_totals[1]['tax'].to_f
    assert_equal @order.shipping_cost, sales_totals[1]['shipping'].to_f
  end

  
  # Test if a csv file with a list of orders will be generated.
  def test_get_csv_for
    order_1 = orders(:santa_next_christmas_order)

    # Order with a blank shipping type, just to cover a comparison in the method.
    order_2 = orders(:an_order_ordered_paid_shipped)
    order_2.order_shipping_type = nil
    
    # Test the CSV.
    csv_string = Order.get_csv_for([order_1, order_2])
    csv_array = FasterCSV.parse(csv_string)

    # Test if the header is right.
    assert_equal csv_array[0], [
      "OrderNumber", "Company", "ShippingType", "Date", 
      "BillLastName", "BillFirstName", "BillAddress", "BillCity", 
      "BillState", "BillZip", "BillCountry", "BillTelephone", 
      "ShipLastName", "ShipFirstName", "ShipAddress", "ShipCity", 
      "ShipState", "ShipZip", "ShipCountry", "ShipTelephone",
      "Item1", "Quantity1", "Item2", "Quantity2", "Item3", "Quantity3", "Item4", "Quantity4",
      "Item5", "Quantity5", "Item6", "Quantity6", "Item7", "Quantity7", "Item8", "Quantity8",
      "Item9", "Quantity9", "Item10", "Quantity10", "Item11", "Quantity11", "Item12", "Quantity12",
      "Item13", "Quantity13", "Item14", "Quantity14", "Item15", "Quantity15", "Item16", "Quantity16"
    ]

   order_arr = []
   orders_list_arr = []
    
    # Test if an order is right.
    for order in [order_1, order_2]
      bill = order.billing_address
      ship = order.shipping_address
      pretty_date = order.created_on.strftime("%m/%d/%y")
      if !order.order_shipping_type.nil?
        ship_code = order.order_shipping_type.code
      else
        ship_code = ''
      end
      order_arr = [
        order.order_number.to_s, '', ship_code, pretty_date,
        bill.last_name, bill.first_name, bill.address, bill.city,
        bill.state, bill.zip, bill.country.name, bill.telephone,
        ship.last_name, ship.first_name, ship.address, ship.city,
        ship.state, ship.zip, ship.country.name, ship.telephone 
      ]
      item_arr = []
      # Generate spaces for items up to 16 deep
      0.upto(15) do |i|
        item = order.order_line_items[i]
        if !item.nil? && !item.product.nil?  then
          item_arr << item.product.code
          item_arr << item.quantity.to_s
        else
          item_arr << ''
          item_arr << ''
        end
      end
      order_arr.concat(item_arr)
      orders_list_arr << order_arr
    end
    assert_equal csv_array[1..2], orders_list_arr
  end

  
  # Test if a xml file with a list of orders will be generated.
  # TODO: Get rid of the reference to fedex code. 
  def test_get_xml_for
    order_1 = orders(:santa_next_christmas_order)

    # Order with a blank shipping type, just to cover a comparison in the method.
    order_2 = orders(:an_order_ordered_paid_shipped)
    order_2.order_shipping_type = nil
    
    # Test the XML.
    require 'rexml/document'
    
    xml = REXML::Document.new(Order.get_xml_for([order_1, order_2]))
    assert xml.root.name, "orders"

    # TODO: For some elements the name don't correspond with the content.
    # This can be tested a little more.
  end

  # INSTANCE METHODS ==========================================================
  
  # Test if the current status of an order will be shown with success.
  def test_status
    assert_equal @order.status, order_status_codes(:ordered_paid_to_ship).name
  end
  
  # Test if we can refer to order_line_items simply using items.
  def test_item_association
    assert_equal @order.order_line_items, @order.items
  end
  
  # Test if we can get the total order value.
  def test_get_total_order_value
    expected_value = @order.line_items_total + @order.shipping_cost + @order.tax_cost
    assert_equal expected_value, @order.total
  end
  
  # Test if we can get the tax total cost for the order.
  def test_get_total_tax_cost
    expected_value = (@order.line_items_total) * (@order.tax/100)
    assert_equal expected_value, @order.tax_cost
  end
  
  # Test if we can refer to the billing address name.
  def test_name
    expected_name = "#{@order.billing_address.first_name} #{@order.billing_address.last_name}"
    assert_equal expected_name, @order.name
    @order.billing_address.destroy
    @order.reload
    assert_equal '', @order.name
  end
  
  # Test if we can refer to order_account simply using account.
  def test_return_account
    assert_equal @order.account, @order.order_account
  end
  
  
  # Test if a hash containing item ids and quantities can be used to fill the list.
  # TODO: Doing that the name of the line item isn't set.
  # TODO: Get rid of this method if it will not be used.
  def test_build_line_items_from_hash
    # Create a new order and put just one line item.
    setup_new_order()
    @o.order_line_items << @li
    
    # Now try to feed it with others.
    @o.line_items = {
      items(:red_lightsaber).id => {'quantity' => 2},
      items(:towel).id => {'quantity' => 1},
      items(:blue_lightsaber).id => {'quantity' => ""}
    }
    
    assert_equal @o.items.size, 2
  end

  
  # Test an order to see if it will correctly say if has a valid transaction id.
  def test_show_if_contains_valid_transaction_id
    assert_equal @order.contains_valid_transaction_id?, false
    assert @order.update_attributes(:auth_transaction_id => 123)
    assert_equal @order.contains_valid_transaction_id?, true
  end
  
  
  # Test an order to see if it will correctly say if has an specific line item.
  # TODO: The comment about how to use this method and how it should really be used are different.
  # TODO: Get rid of this method if it will not be used.
  def test_show_if_has_line_item
    assert_equal @order.has_line_item?(@order.order_line_items.find_by_name(items(:towel).name).id), true

    # Create a new order and put just one line item.
    new_order_line_item = OrderLineItem.for_product(items(:small_stuff))
    new_order = Order.new
    new_order.order_line_items << new_order_line_item
    assert new_order.save
    
    # Search for an existent line item of ANOTHER order.
    assert_equal @order.has_line_item?(new_order.order_line_items.find_by_name(items(:small_stuff).name).id), false
  end
  
  # Test that we round to the cent for costs
  def test_round_totals
    # tax, total want to be rounded
    @order.tax = 0.068
    assert_equal @order.tax_cost, 0.88
    assert_equal 1326.38, @order.total
  end
  
  
  # Test an order to see if it will correctly say how many products it have in a line item.
  # TODO: The comment about how to use this method and how it is really being used are different.
  # Why use a line item id, it is meaningless. Probably the current use and the method code are wrong.
  def test_get_line_item_quantity
    assert_equal @order.get_line_item_quantity(@order.order_line_items.find_by_name(items(:towel).name).id), order_line_items(:santa_next_christmas_order_item_6).quantity

    # Create a new order and put just one line item.
    new_order_line_item = OrderLineItem.for_product(items(:small_stuff))
    new_order = Order.new
    new_order.order_line_items << new_order_line_item
    assert new_order.save
    
    # Search for an existent line item of ANOTHER order.
    assert_equal @order.get_line_item_quantity(new_order.order_line_items.find_by_name(items(:small_stuff).name).id), 0
  end


  # Test an order to see if it will correctly show a specific line item total.
  # TODO: The comment about how to use this method and how it is really being used are different.
  # Why use a line item id, it is meaningless. Probably the current use and the method code are wrong.
  def test_get_line_item_total
    assert_equal @order.get_line_item_total(@order.order_line_items.find_by_name(items(:towel).name).id), order_line_items(:santa_next_christmas_order_item_6).total

    # Create a new order and put just one line item.
    new_order_line_item = OrderLineItem.for_product(items(:small_stuff))
    new_order = Order.new
    new_order.order_line_items << new_order_line_item
    assert new_order.save
    
    # Search for an existent line item of ANOTHER order.
    assert_equal @order.get_line_item_total(new_order.order_line_items.find_by_name(items(:small_stuff).name).id), 0
  end


  # Test an order to see if it will correctly show all line items total.
  def test_get_all_line_items_total
    assert_equal @order.line_items_total, @order.order_line_items.collect{ |p| p.unit_price * p.quantity }.sum
  end

  # Test an order to see if the correct total weight will be returned.
  def test_return_total_weight
    calculated_weight = 0
    @order.order_line_items.each do |item|
      calculated_weight += item.quantity * item.product.weight
    end
    assert_equal @order.weight, calculated_weight
  end
  
  # Test an order to see if a flat shipping price will be returned.
  # TODO: Should this method really be here?
  def test_get_flat_shipping_price
    assert_equal @order.get_flat_shipping_price, Preference.find_by_name('store_handling_fee').value.to_f
  end
  
  # Test an order to see if the correct shipping prices will be returned.
  def test_get_shipping_prices
    # Test a national shipping order.
    assert_same_elements @order.get_shipping_prices, OrderShippingType.get_domestic
    
    # Turn it into an international one and test.
    an_address = order_addresses(:santa_address)
    an_address.country = countries(:GB)
    an_address.save
    @order.reload
    assert_same_elements @order.get_shipping_prices, OrderShippingType.get_foreign
    
    # Now we say that we are in that same other country.
    prefs = {
      "store_home_country" => countries(:GB).id
    }
    assert Preference.save_settings(prefs)
    
    # And that same shipment should be national now.
    assert_same_elements @order.get_shipping_prices, OrderShippingType.get_domestic
  end
  
  
  # Run a payment transaction of the type defined in preferences.
  def test_run_transaction_authorize
    assert Preference.save_settings({ "cc_processor" => "Authorize.net" })
    Order.any_instance.expects(:run_transaction_authorize).once.returns('executed_authorize')
    assert_equal @order.run_transaction, "executed_authorize"
  end

  def test_run_transaction_paypal_ipn
    # Now we say that we will use paypal ipn. Mock the method and test it.
    assert Preference.save_settings({ "cc_processor" => "PayPal IPN" })
    Order.any_instance.expects(:run_transaction_paypal_ipn).once.returns('executed_paypal_ipn')
    assert_equal @order.run_transaction, "executed_paypal_ipn"
  end

  def test_run_transaction_invalid
    # Now we say that we will use a non existent processor.
    assert Preference.save_settings({ "cc_processor" => "Nonexistent" })
    assert_throws(:"The currently set preference for cc_processor is not recognized. You might want to add it to the code..."){@order.run_transaction}
  end


  # Test an order to see if the cc processor will be returned.
  def test_get_cc_processor
    # TODO: Should this method really be here?
    assert_equal Order.get_cc_processor, Preference.find_by_name('cc_processor').value.to_s
  end


  # Test an order to see if the cc login will be returned.
  def test_get_cc_login
    # TODO: Should this method really be here?
    assert_equal Order.get_cc_login, Preference.find_by_name('cc_login').value.to_s
  end


  # Run an Authorize.net payment transaction with success.
  def test_run_transaction_authorize_with_success
    # Setup the mailer.
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    initial_mbox_length = ActionMailer::Base.deliveries.length
    
    # Create a standard success response. Parameters: success, message, params = {}, options = {}
    a_positive_response = ActiveMerchant::Billing::Response.new(
      true,
      "(TESTMODE) This transaction has been approved",
      {
        :response_reason_text => "(TESTMODE) This transaction has been approved.",
        :response_reason_code => "1",
        :response_code => "1",
        :avs_message => "Address verification not applicable for this transaction",
        :transaction_id => "0",
        :avs_result_code => "P",
        :card_code => nil
     }, {
        :test => true,
        :authorization => "0",
        :fraud_review => false
      }
    )
    
    # Stub the purchase method to not call home (using commit) and return a standard success response.
    ActiveMerchant::Billing::AuthorizeNetGateway.any_instance.stubs(:purchase).returns(a_positive_response)

    # Assert that with a success response the method will return true.
    assert_equal @order.run_transaction_authorize, true

    # We should have received a mail about that.
    assert_equal ActionMailer::Base.deliveries.length, initial_mbox_length + 1
 
    
    # Stub the deliver_receipt method to raise an exception.
    Order.any_instance.stubs(:deliver_receipt).raises('An error!')
    
    # Run the transaction again.
    @order.run_transaction_authorize
    # We don't need to assert the raise because it will be caugh in run_transaction_authorize.

    # We should NOT have received a mail about that.
    assert_equal ActionMailer::Base.deliveries.length, initial_mbox_length + 1
  end


  # Run an Authorize.net payment transaction with failure.
  def test_run_transaction_authorize_with_failure
    # Setup the mailer.
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    initial_mbox_length = ActionMailer::Base.deliveries.length
    
    # Create a standard failure response when cc number is wrong. Parameters: success, message, params = {}, options = {}
    a_negative_response = ActiveMerchant::Billing::Response.new(
      false,
      "(TESTMODE) The credit card number is invalid",
      {
        :response_reason_text => "(TESTMODE) The credit card number is invalid.",
        :response_reason_code => "6",
        :response_code => "3",
        :avs_message => "Address verification not applicable for this transaction",
        :transaction_id => "0",
        :avs_result_code => "P",
        :card_code => nil
     }, {
        :test => true,
        :authorization => "0",
        :fraud_review => false
      }
    )
    
    # Stub the purchase method to not call home (using commit) and return a standard failure response.
    ActiveMerchant::Billing::AuthorizeNetGateway.any_instance.stubs(:purchase).returns(a_negative_response)

    # Assert that with a failure response the method will return the response message.
    assert_equal @order.run_transaction_authorize, a_negative_response.message

    # We should have received a mail about that.
    assert_equal ActionMailer::Base.deliveries.length, initial_mbox_length + 1
 
    
    # Stub the deliver_failed method to raise an exception.
    Order.any_instance.stubs(:deliver_failed).raises('An error!')
    
    # Run the transaction again.
    @order.run_transaction_authorize
    # We don't need to assert the raise because it will be caugh in run_transaction_authorize.

    # We should NOT have received a mail about that.
    assert_equal ActionMailer::Base.deliveries.length, initial_mbox_length + 1
  end


  # Run an Paypal IPN payment transaction.
  # TODO: This method don't run a transaction, it only change the status code and add a note.
  # TODO: Could't configure Paypal IPN to work.
  def test_run_transaction_paypal_ipn
    notes = "Original notes"
    setup_new_order()

    @o.notes = notes.dup
    assert @o.save

    # Running it should return the new status code.
    assert_equal @o.run_transaction_paypal_ipn, order_status_codes(:on_hold_awaiting_payment).id
    # A new note should be added.
    assert_not_equal notes, @o.notes
  end


  # Test the cleaning of a successful order.
  def test_cleanup_successful
    setup_new_order()
    @o.order_line_items << @li
    @o.order_status_code = order_status_codes(:cart)
    @o.notes = "test test"
    assert @o.save

    # Make sure inventory control is enabled.
    assert Preference.find_by_name('store_use_inventory_control').is_true?
    # Make sure cc number obfuscation is enabled.
    assert Preference.find_by_name('cc_clear_after_order').is_true?
    
    initial_quantity = @li.item.quantity
    notes_before = @o.notes.clone
    
    @o.cleanup_successful
    @li.item.reload
    
    # Quantity should be updated.
    assert_equal @li.item.quantity, (initial_quantity - @li.quantity)
    # Status code should be updated.
    @o.reload
    assert_equal @o.order_status_code, order_status_codes(:ordered_paid_to_ship)
    
    # CC number should be obfuscated.
    number_len = @o.account.cc_number.length
    new_cc_number = @o.account.cc_number[number_len - 4, number_len].rjust(number_len, 'X')
    assert_equal @o.account.cc_number, new_cc_number
    
    # A new note should be added.
    notes_after = @o.notes
    assert_not_equal notes_before, notes_after
  end


  # Test the cleaning of a failed order.
  def test_cleanup_failed
    setup_new_order()
    @o.order_line_items << @li
    @o.order_status_code = order_status_codes(:cart)
    @o.notes = "test test"
    assert @o.save
    
    notes_before = @o.notes.dup

    @o.cleanup_failed("A message!")
    
    # Status code should be updated.
    assert_equal @o.order_status_code, order_status_codes(:on_hold_payment_failed)
    # A new note should be added.
    notes_after = @o.notes
    assert_not_equal notes_before, notes_after
  end


  # Test the deliver of the e-mail message in case of success.
  def test_deliver_receipt
    # Setup the mailer.
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    initial_mbox_length = ActionMailer::Base.deliveries.length

    # Get any order.
    @order.deliver_receipt    

    # We should have received a mail about that.
    assert_equal ActionMailer::Base.deliveries.length, initial_mbox_length + 1
    
    receipt_content = ContentNode.find(:first, :conditions => ["name = ?", 'OrderReceipt'])
    
    # Create a block that guarantees that the content node name will be recovered.
    begin
      assert receipt_content.update_attributes(:name => 'order_receipt')

      @order.deliver_receipt    

      # We should NOT have received a mail about that.
      assert_equal ActionMailer::Base.deliveries.length, initial_mbox_length + 1
    ensure
      # Put the name back.
      assert receipt_content.update_attributes(:name => 'OrderReceipt')
    end
  end


  # Test the deliver of the e-mail message in case of error.
  def test_deliver_failed
    # Setup the mailer.
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    initial_mbox_length = ActionMailer::Base.deliveries.length

    @order.deliver_failed    

    # We should have received a mail about that.
    assert_equal ActionMailer::Base.deliveries.length, initial_mbox_length + 1
  end
  

  # Test the order have a promotion applied.
  def test_say_if_is_discounted
    setup_new_order_with_items()
    promo = promotions(:percent_rebate)
    
    assert !@order.is_discounted?
    @order.promotion_code = promo.code
    assert @order.is_discounted?
  end
    
  # PAYPAL IPN TESTS ----------------------------------------------------------
    
  def setup_test_ipn
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    @notes_before = @order.notes.dup
    # Set a fake fixed transaction id.
    @txn_id = "3HY99478SV091020H"
    # TODO: Take a look closely how these params are filled in the paypal guides.
    # Create a fake hash to be used as params and to generate the query string.
    @fake_params = {
      :address_city => "San Jose",
      :address_country => "United States",
      :address_country_code => "US",
      :address_name => "Test User",
      :address_state => "CA",
      :address_status => "confirmed",
      :address_street => "1 Main St",
      :address_zip => "95131",
      :business => "seller@my.own.store",
      :charset => "windows-1252",
      :custom => "",
      :first_name => "Test",
      :last_name => "User",
      :invoice => @order.order_number,
      :item_name1 => @order.order_line_items[0].name,
      :item_name2 => @order.order_line_items[1].name,
      :item_number1 => "",
      :item_number2 => "",
      :mc_currency => "USD",
      :mc_fee => "0.93",
      :mc_gross => @order.line_items_total + @order.shipping_cost,
      # Why the shipping cost is here?
      :mc_gross_1 => @order.order_line_items[0].total + @order.shipping_cost,
      :mc_gross_2 => @order.order_line_items[1].total,
      :mc_handling => "0.00",
      :mc_handling1 => "0.00",
      :mc_handling2 => "0.00",
      :mc_shipping => @order.shipping_cost,
      :mc_shipping1 => @order.shipping_cost,
      :mc_shipping2 => "0.00",
      :notify_version => "2.4",
      :num_cart_items => @order.order_line_items.length,
      :payer_email => "buyer@my.own.store",
      :payer_id => "3GQ2THTEB86ES",
      :payer_status => "verified",
      :payment_date => "08:41:36 May 28, 2008 PDT",
      :payment_fee => "0.93",
      :payment_gross => "21.75",
      :payment_status => "Completed",
      :payment_type => "instant",
      :quantity1 => @order.order_line_items[0].quantity,
      :quantity2 => @order.order_line_items[1].quantity,
      :receiver_email => "seller@my.own.store",
      :receiver_id => "TFLJN8N28W6VW",
      :residence_country => "US",
      :tax => "0.00",
      :tax1 => "0.00",
      :tax2 => "0.00",
      :test_ipn => "1",
      :txn_id => "53B76609FE637874A",
      :txn_type => "cart",
      :verify_sign => "AKYASk7fkoMqSjT.TB-8hzZ9riLTAVyg5ho1FZd9XrCkuXZCpp-Q6uEY",
      :memo => "A message."
    }
    # Configure the Paypal store login.
    assert Preference.save_settings({ "cc_login" => @fake_params[:business] })
    # Create the parameters required by the matches_ipn method.
    @notification = ActiveMerchant::Billing::Integrations::Paypal::Notification.new(@fake_params.to_query)
    @complete_params = @fake_params.merge({ :action => "ipn", :controller => "paypal" })
  end

  # Test if the contents of the IPN posted back are in conformity 
  # with what was sent, here the IPN is validated.
  def test_matches_ipn_success
    setup_new_order_with_items()
    setup_test_ipn()

    assert @order.matches_ipn?(@notification, @complete_params)
  end

  def test_matches_ipn_fail_mc_gross
    setup_new_order_with_items()
    setup_test_ipn()
    
    wrong_notification = ActiveMerchant::Billing::Integrations::Paypal::Notification.new(
     @fake_params.merge({ :mc_gross => "2.00" }).to_query
    )
    assert(
      !@order.matches_ipn?(wrong_notification, @complete_params), 
      "Should have failed because :mc_gross."
    )
  end

  def test_matches_ipn_fail_business_email
    setup_new_order_with_items()
    setup_test_ipn()
    
    assert(
      !@order.matches_ipn?(
        @notification, 
        @complete_params.merge({ :business => "somebody@else" })
      ), 
      "Should have failed because :business."
    )
  end
  
  def test_matches_ipn_fail_duplicate_txn_id
    setup_new_order_with_items()
    setup_test_ipn()
    
    # It should fail if finds another order with the same txn_id.
    another_order = orders(:santa_next_christmas_order)
    another_order.auth_transaction_id = @fake_params[:txn_id]
    another_order.save
    assert(
      !@order.matches_ipn?(@notification, @complete_params), 
      "Should have failed because another order already have this txn_id."
    )
  end

  # Test the method that mark the order with a success status, 
  # if everything is fine with the IPN received.
  def test_pass_ipn
    setup_test_ipn()
    # Exercise
    assert_difference "ActionMailer::Base.deliveries.length" do
      @order.pass_ipn(@txn_id)
    end

    # Verify
    assert_equal @order.auth_transaction_id, @txn_id
    assert_not_equal @notes_before, @order.notes
  end
    
  def test_pass_ipn_raises_error
    setup_test_ipn()
    # Stub the deliver_receipt method to raise an exception.
    Order.any_instance.stubs(:deliver_receipt).raises('An error!')
    # We don't need to assert the raise because it will be caugh in pass_ipn.
    # Pass the order and the fake txn_id.
    assert_no_difference "ActionMailer::Base.deliveries.length" do
      @order.pass_ipn(@txn_id)
    end
  end
  
  # Test the method that mark the order with a fail status, 
  # if something is wrong with the IPN received.
  def test_fail_ipn
    setup_test_ipn()
    
    # Exercise
    assert_difference "ActionMailer::Base.deliveries.length" do
      @order.fail_ipn()
    end
    
    # TODO: The status code is being redefined in this method without need.
    # It will be redefined again in order.cleanup_failed.
    notes_after = @order.notes
    assert_not_equal @notes_before, @order.notes
  end
  
  def test_fail_ipn_raises_error
    setup_test_ipn()
  
    # Stub the deliver_receipt method to raise an exception.
    Order.any_instance.stubs(:deliver_failed).raises('An error!')
    
    assert_no_difference "ActionMailer::Base.deliveries.length" do
      @order.fail_ipn()
    end
  end

  # / PAYPAL ------------------------------------------------------------------

  #############################################################################
  # CART COMPATIBILITY METHODS
  #
  # These tests are to ensure compatibility of Order with the Cart object
  # which has been removed.
  #############################################################################
  
  
  def test_empty
    order = orders(:santa_next_christmas_order)
    assert !order.empty?
    assert order.order_line_items.size > 0
    order.empty!
    assert order.empty?
    assert_equal order.order_line_items.size, 0
  end
  
  # When created the cart should be empty.
  def test_when_created_be_empty
    a_cart = Order.new
    
    assert_equal a_cart.items.size, 0
    assert_equal a_cart.tax, 0.0
    assert_equal a_cart.total, 0.0
    assert_equal a_cart.shipping_cost, 0.0
  end

  def test_new_notes_setter
    # Notes need to be NIL in order to test an edge case error.
    @order.update_attribute(:notes, nil)
    # ^^ DONT REMOVE THIS
    @order.update_attributes({
      :new_notes => 'Hello world.'
    })
    @order.reload
    assert_not_nil @order.notes
    assert @order.notes.include?("<span class=\"info\">")
  end

  # AFFILIATE CODE
  
  def test_affiliate_code_setter_invalid
    fake_code = 'bogus_affiliate_code'
    @order.expects(:promotion_code=).with(fake_code)
    @order.affiliate_code = fake_code
    # Verify
    assert @order.affiliate.nil?, @order.affiliate.inspect
  end
  
  def test_affiliate_code_setter_nil
    assert_nothing_raised { @order.affiliate_code = nil }
  end
  
  def test_affiliate_code_setter_valid
    affil = affiliates(:joes_marketing)
    @order.expects(:promotion_code=).with(affil.code)
    @order.affiliate_code = affil.code
    # Verify
    assert @order.save
    assert_equal affil.code, @order.affiliate_code
    assert_equal affil, @order.affiliate
  end

  # Test if a product can be added to the cart.
  def test_add_product
    a_cart = Order.new
    a_cart.add_product(items(:red_lightsaber), 1)
    a_cart.add_product(items(:red_lightsaber), 3)
    assert_equal 1, a_cart.items.length, "Cart added multiple order line items for the same product. #{a_cart.items.inspect}"
    assert a_cart.save
    a_cart.reload()
    assert_equal 1, a_cart.items.length
    assert_equal 4, a_cart.items[0].quantity
  end
  
  # Test if a add_product properly handles negative quantities
  def test_add_product_with_negative_quantity
    a_cart = Order.new
    a_cart.add_product(items(:blue_lightsaber), 2)
    a_cart.add_product(items(:blue_lightsaber), -1)
    a_cart.reload
    # Calling add_product with a negative quantity should remove that many units
    assert_equal 1, a_cart.items[0].quantity
    a_cart.add_product(items(:blue_lightsaber), -3)    
#    a_cart.reload
    assert a_cart.empty?
  end

  # Test if a product can be removed from the cart.
  def test_remove_product
    o = Order.new
    o.expects(:cleanup_promotion).times(4)
    o.add_product(items(:red_lightsaber), 2)
    o.add_product(items(:blue_lightsaber), 2)
    assert_equal o.items.length, 2

    # When not specified a quantity all units from the product will be removed.
    o.remove_product(items(:blue_lightsaber))
    assert_equal o.items.length, 1

    # When specified a quantity, just these units from the product will be removed.
    o.remove_product(items(:red_lightsaber), 1)
    assert_equal o.items.length, 1

    # It should not be empty.
    assert !o.empty?

    # Now it should be empty.
    o.remove_product(items(:red_lightsaber), 1)
    assert o.empty?
  end


  # Test if what is in the cart is really available in the inventory.
  def test_check_inventory
    # Create a cart and add some products.
    a_cart = Order.new
    a_cart.add_product(items(:red_lightsaber), 2)
    a_cart.add_product(items(:blue_lightsaber), 4)
    assert_equal a_cart.items.length, 2
    
    an_out_of_stock_product = items(:red_lightsaber)
    assert an_out_of_stock_product.update_attributes(:quantity => 1)
    
    # Assert that the product that was out of stock was removed.
    removed_products = a_cart.check_inventory
    assert_equal removed_products, [an_out_of_stock_product.name]

    # Should last the right quantity of the rest.
    assert_equal a_cart.items.length, 1
  end
  
  def test_check_inventory_with_promotion
    # Create cart, add item & promotion
    a_cart = Order.new
    a_cart.add_product(items(:red_lightsaber), 2)
    a_cart.promotion_code = "FIXED_REBATE"
    assert a_cart.save
    assert_nothing_raised do
      a_cart.check_inventory
    end
  end
  
  
  # Test if will return the total price of products in the cart.
  def test_return_total_price
    # Create a cart and add some products.
    a_cart = Order.new
    a_cart.add_product(items(:red_lightsaber), 2)
    a_cart.add_product(items(:blue_lightsaber), 4)
    assert_equal a_cart.items.length, 2

    total = 0.0
    for item in a_cart.items
      total += (item.quantity * item.unit_price)
    end

    assert_equal total, a_cart.total
  end
  
  def test_affiliate_earnings
    @order.stubs(:line_items_total).returns(100)
    @order.stubs(:shipping_cost).returns(20)
    @order.stubs(:tax_cost).returns(50)
    expected = @order.line_items_total * (Affiliate.get_revenue_percentage.to_f/100)
    @order.expects(:is_payable_to_affiliate?).times(2).returns(true, false)
    assert_equal expected, @order.affiliate_earnings
    assert_equal 0, @order.affiliate_earnings
  end
  
  def test_is_payable_to_affiliate
    payable_statuses = [
      order_status_codes(:ordered_paid_shipped),
      order_status_codes(:sent_to_fulfillment)
    ]
    OrderStatusCode.find(:all).each do |stat|
      @order.order_status_code = stat
      
      assert_equal(
        payable_statuses.include?(stat),
        @order.is_payable_to_affiliate?,
        "Fail for #{stat.inspect}"
      )
    end
  end
  
  def test_is_complete
    complete_statuses = [
      order_status_codes(:ordered_paid_to_ship), 
      order_status_codes(:ordered_paid_shipped), 
      order_status_codes(:sent_to_fulfillment), 
      order_status_codes(:cancelled), 
      order_status_codes(:returned)
    ]
    OrderStatusCode.find(:all).each do |stat|
      @order.order_status_code = stat
      
      assert_equal(
        complete_statuses.include?(stat),
        @order.is_complete?,
        "Fail for #{stat.inspect}"
      )
    end
  end

  # Test if the right status codes will be shown as editable.
  def test_is_editable_success
    editable_statuses = [
      order_status_codes(:cart), 
      order_status_codes(:to_charge), 
      order_status_codes(:on_hold_payment_failed),
      order_status_codes(:on_hold_awaiting_payment), 
      order_status_codes(:ordered_paid_to_ship)
    ]
    OrderStatusCode.find(:all).each do |stat|
      @order.order_status_code = stat
      
      assert_equal(
        editable_statuses.include?(stat),
        @order.is_editable?,
        "Fail for #{stat.inspect}"
      )
    end
  end

  # Test if will return the tax cost for the total in the cart.
  def test_return_tax_cost
    # Create a cart and add some products.
    a_cart = Order.new
    a_cart.add_product(items(:red_lightsaber), 2)
    a_cart.add_product(items(:blue_lightsaber), 4)
    
    # By default tax is zero.
    assert_equal a_cart.tax_cost, a_cart.total * a_cart.tax
  end

  # Test if will return the line items total.
  def test_return_line_items_total
    # Create a cart and add some products.
    a_cart = Order.new
    a_cart.add_product(items(:red_lightsaber), 2)
    a_cart.add_product(items(:blue_lightsaber), 4)
    
    assert_equal a_cart.line_items_total, a_cart.total
  end

  def test_has_downloads
    assert_equal 1, @order.downloads.count
    assert_equal items(:towel).downloads, @order.downloads
  end

end
