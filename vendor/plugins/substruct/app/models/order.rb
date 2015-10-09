class Order < ActiveRecord::Base  
  # Associations
  has_many :order_line_items, :dependent => :destroy
  alias items order_line_items
  
  # billing_address defined as a method!
  belongs_to :billing_address, 
    :class_name => 'OrderAddress',
    :foreign_key => 'billing_address_id'
  belongs_to :shipping_address,
    :class_name => 'OrderAddress',
    :foreign_key => 'shipping_address_id'
  belongs_to :order_account
  alias account order_account

  # Alias better name than "order_user"
  belongs_to :customer, :class_name => 'OrderUser', :foreign_key => 'order_user_id' 
  belongs_to :order_user

  belongs_to :order_shipping_type
  belongs_to :order_status_code
  belongs_to :promotion
  belongs_to :affiliate
  belongs_to :affiliate_payment
  
  has_many :downloads, 
    :finder_sql => %q\
      SELECT * FROM user_uploads
      WHERE user_uploads.type = 'Download'
      AND user_uploads.id IN (
        SELECT download_id FROM product_downloads
        WHERE product_downloads.product_id IN (
          SELECT item_id FROM order_line_items
          WHERE order_id = #{id}
        )
      )
    \,
    :counter_sql => %q\
      SELECT COUNT(*) FROM user_uploads
      WHERE user_uploads.type = 'Download'
      AND user_uploads.id IN (
        SELECT download_id FROM product_downloads
        WHERE product_downloads.product_id IN (
          SELECT item_id FROM order_line_items
          WHERE order_id = #{id}
        )
      )
    \

  attr_reader :new_notes

  # VALIDATION ================================================================
  validates_presence_of :order_number
  validates_uniqueness_of :order_number

  # INITIALIZE ================================================================
  
  # Sets all new Order objects to have status of CART.
  def initialize(*args)
    super(*args)
    self.order_status_code = OrderStatusCode.find_by_name('CART')
  end

  # CALLBACKS =================================================================
  
  before_create :set_order_number
  def set_order_number
    self.order_number = Order.generate_order_number
    return true
  end
  
  def before_save
    set_product_cost
    cleanup_promotion
  end
  
  # Sets product cost based on line items total before a save.
  def set_product_cost
    self.product_cost = self.line_items_total
    return true
  end
  
  # Ensures that customers can't apply discounts, then remove items
  # and still have those discounts applied.
  def cleanup_promotion
    # Only applies when order is editable.
    return true unless self.is_editable?

    if self.promotion && !self.should_promotion_be_applied?(self.promotion)
      self.remove_promotion
    end
    return true
  end
  
  # CLASS METHODS =============================================================

  # Searches an order
  # Uses order number, first name, last name
  def self.search(search_term, count=false, limit_sql=nil)
    if (count == true) then
      sql = "SELECT COUNT(*) "
    else
      sql = "SELECT orders.* "
    end
    sql << "FROM orders "
    sql << "INNER JOIN order_addresses AS billing_address ON (orders.billing_address_id = billing_address.id)"
    sql << "INNER JOIN order_addresses AS shipping_address ON (orders.shipping_address_id = shipping_address.id)"
    sql << "WHERE orders.order_number = ? "
    sql << "OR CONCAT(billing_address.first_name, ' ', billing_address.last_name) LIKE ? "
    sql << "OR CONCAT(shipping_address.first_name, ' ', shipping_address.last_name) LIKE ? "
    sql << "ORDER BY orders.created_on DESC "
    sql << "LIMIT #{limit_sql}" if limit_sql
    arg_arr = [sql, search_term, "%#{search_term}%", "%#{search_term}%"]
    if (count == true) then
      count_by_sql(arg_arr)
    else
      find_by_sql(arg_arr)
    end
  end
  
  # Finds all completed orders 
  # and allows for passing standard "find" arguments in.
  def self.find_completed(args={}, options={})
    orders = []
    with_scope(:find => { 
      :conditions => [
        "(order_status_code_id = 5 OR order_status_code_id = 6 OR order_status_code_id = 7)"
      ] 
    }) do
      orders = find(args, options)
    end
    return orders
  end
  
  # Finds orders by country
  def self.find_by_country(country_id, count=false, limit_sql=nil)
    if (count == true) then
      sql = "SELECT COUNT(*) "
    else
      sql = "SELECT DISTINCT orders.* "
    end
    sql << "FROM orders "
    sql << "INNER JOIN order_users ON order_users.id = orders.order_user_id "
    sql << "INNER JOIN order_addresses ON ( "
    sql << "  order_addresses.country_id = ? AND order_addresses.order_user_id = order_users.id "
    sql << ")"
    arg_arr = [sql, country_id]
    if (count == true) then
      count_by_sql(arg_arr)
    else
      find_by_sql(arg_arr)
    end
  end
  
  # Removes any empty CARTS that are older than a day
  def self.destroy_old_carts
    Order.destroy_all(%Q\
      order_status_code_id = 1 
      AND DATE(created_on) < CURRENT_DATE 
    \)
  end

  # Generates a unique order number.
  # This number isn't ID because we want to mask that from the customers.
  def self.generate_order_number
    record = Object.new
    while record
      random = rand(999999999)
      record = find(:first, :conditions => ["order_number = ?", random])
    end
    return random
  end

  # Returns array of sales totals (hash) for a given year.
  # Hash contains
  #   * :number_of_sales
  #   * :sales_total
  #   * :tax
  #   * :shipping
  def self.get_totals_for_year(year)
    months = Array.new
    0.upto(12) { |i|
      sql = "SELECT COUNT(*) AS number_of_sales, SUM(product_cost) AS sales_total, "
      sql << "SUM(tax) AS tax, SUM(shipping_cost) AS shipping "
      sql << "FROM orders "
      sql << "WHERE YEAR(created_on) = ? "
      if i != 0 then
        sql << "AND MONTH(created_on) = ? "
      end
      sql << "AND (order_status_code_id = 5 OR order_status_code_id = 6 OR order_status_code_id = 7) "
      sql << "LIMIT 0,1"
      if i != 0 then
        months[i] = self.find_by_sql([sql, year, i])[0]
      else
        months[i] = self.find_by_sql([sql, year])[0]
      end
    }
    return months
  end

  # Gets a CSV string that represents an order list.
  def self.get_csv_for(order_list)
    require 'fastercsv'
    csv_string = FasterCSV.generate do |csv|
      # Do header generation 1st
      csv << [
        "OrderNumber", "Company", "ShippingType", "Date", 
        "BillLastName", "BillFirstName", "BillAddress", "BillCity", 
        "BillState", "BillZip", "BillCountry", "BillTelephone", 
        "ShipLastName", "ShipFirstName", "ShipAddress", "ShipCity", 
        "ShipState", "ShipZip", "ShipCountry", "ShipTelephone",
        "Item1",
        "Quantity1", "Item2", "Quantity2", "Item3", "Quantity3", "Item4",
        "Quantity4", "Item5", "Quantity5", "Item6", "Quantity6", "Item7",
        "Quantity7", "Item8", "Quantity8", "Item9", "Quantity9", "Item10",
        "Quantity10", "Item11", "Quantity11", "Item12", "Quantity12", "Item13",
        "Quantity13", "Item14", "Quantity14", "Item15", "Quantity15", "Item16",
        "Quantity16"
      ]
      for order in order_list
        bill = order.billing_address
        ship = order.shipping_address
        pretty_date = order.created_on.strftime("%m/%d/%y")
        if !order.order_shipping_type.nil?
          ship_code = order.order_shipping_type.code
        else
          ship_code = ''
        end
        
        bill_country = bill.country.name rescue ''
        ship_country = ship.country.name rescue ''
        
        order_arr = [
          order.order_number, '', ship_code, pretty_date,
          bill.last_name, bill.first_name, bill.address, bill.city,
          bill.state, bill.zip, bill_country, bill.telephone,
          ship.last_name, ship.first_name, ship.address, ship.city,
          ship.state, ship.zip, ship_country, ship.telephone 
        ]
        item_arr = []
        # Generate spaces for items up to 16 deep
        0.upto(15) do |i|
          item = order.order_line_items[i]
          if !item.nil? && !item.product.nil?  then
            item_arr << item.product.code
            item_arr << item.quantity
          else
            item_arr << ''
            item_arr << ''
          end
        end
        # Add csv string by joining arrays
        csv << order_arr.concat(item_arr)
      end
    end
    return csv_string
  end

  # Returns an XML string for each order in the order list.
  # This format is for sending orders to Tony's Fine Foods
  def self.get_xml_for(order_list)
    xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    xml << "<orders>\n"
    for order in order_list
      if order.order_shipping_type
        shipping_type = order.order_shipping_type.code
      else
        shipping_type = ''
      end
      pretty_date = order.created_on.strftime("%m/%d/%y")
      xml << "  <order>\n"
      xml << "    <date>#{pretty_date}</date>\n"
      xml << "    <shippingCode>#{shipping_type}</shippingCode>\n"
      xml << "    <invoiceNumber>#{order.order_number}</invoiceNumber>\n"
      xml << "    <emailAddress>#{order.order_user.email_address}</emailAddress>\n"
      # Shipping address
      address = order.shipping_address
      xml << "    <shippingAddress>\n"
      xml << "      <firstName>#{address.first_name}</firstName>\n"
      xml << "      <lastName>#{address.last_name}</lastName>\n"
      xml << "      <address1>#{address.address}</address1>\n"
      xml << "      <address2></address2>\n"
      xml << "      <city>#{address.city}</city>\n"
      xml << "      <state>#{address.state}</state>\n"
      xml << "      <zip>#{address.zip}</zip>\n"
      xml << "      <countryCode>#{address.country.code}</countryCode>\n"
      xml << "      <telephone>#{address.telephone}</telephone>\n"
      xml << "    </shippingAddress>\n"
      # Items
      xml << "    <items>\n"
      for item in order.order_line_items
        xml << "      <item>\n"
        xml << "        <name>#{item.product.name}</name>\n"
        xml << "        <id>#{item.product.code}</id>\n"
        xml << "        <quantity>#{item.quantity}</quantity>\n"
        xml << "      </item>\n"
      end
      xml << "    </items>\n"
      # End
      xml << "  </order>\n"
    end
    # End orders
    xml << "</orders>\n"
    return xml
  end
  
  # Check to see which cc processor is used
  def self.get_cc_processor
    Preference.find_by_name('cc_processor').value
  end

  # Get the login info for the cc processor (if any)
  def self.get_cc_login
    Preference.find_by_name('cc_login').value
  end

  # INSTANCE METHODS ==========================================================

  # Removes promotion from object in memory and stored in database.
  #
  # This is necessary because we call it before saves, along with using it
  # as a callback and when removing items.
  def remove_promotion
    # Don't allow more than one promotion?
    # This destroys any line items created previously.
    while self.promotion_line_item
      self.order_line_items.delete(self.promotion_line_item)
    end
    self.promotion = nil
    # Update db without callback being fired
    unless self.new_record?
      Order.update(self.id, {:promotion_id => 0})
    end
  end
  
  # Should a promotion be applied to this order?
  #
  # Happens when applying new promotions, and checking old ones already
  # applied.
  #
  # COULD BE CALLED SHOULD_BE_REMOVED AS WELL.
  def should_promotion_be_applied?(promo)
    unless promo && promo.is_active?
      return false
    else
      # If the order has no items, or just has the promotion line item
      # applied - remove it. We shouldn't be giving discounts to orders
      # with no items at all. Doesn't make sense.
      if (
        self.order_line_items.size == 0 || 
        (self.order_line_items.size == 1 && self.promotion_line_item)
      )
        return false
      end
        
      if promo.minimum_cart_value
        cart_min_passed = (self.line_items_total(false) >= promo.minimum_cart_value)
        return cart_min_passed
      end
      if promo.discount_type == Promotion::TYPES['Buy [n] get 1 free']
        buy_n_item = self.order_line_items.detect { |i| i.item_id == promo.item_id }
        return buy_n_item && buy_n_item.quantity >= promo.discount_amount.to_i
      end
      return true
    end
  end

  # Modifies the order based on any promotion codes passed in.
  # This can add discounts to the order or add items.
  # Returns silently and doesn't add the promo if something is wrong.
  def promotion_code=(code)
    sanitized_code = code.strip unless code.blank?
    # Find promotion based on code entered
    promo = Promotion.find(
      :first,
      :conditions => ["code = ?", sanitized_code]
    )
    # Don't apply the same promotion multiple times.
    return false if self.promotion == promo
    # Don't add the above line to "should_be_applied"
    # as that method also determines if a promo should be REMOVED.
    return unless self.should_promotion_be_applied?(promo)
    
    # Clear any previous promotions & items
    self.remove_promotion()
            
    # Add any line items necessary from promotion.
    oli = OrderLineItem.new
    logger.info "CREATED OLI"
    # Set name & item...
    oli.name = promo.description
    oli.item_id = promo.item_id
    
    # Figure out how to apply the promotion
    case promo.discount_type
      when Promotion::TYPES['Dollars'] then
        oli.quantity = 1
        oli.unit_price = -promo.discount_amount
      when Promotion::TYPES['Percent of total order'] then
        oli.quantity = 1
        oli.unit_price = -(self.line_items_total(false) * (promo.discount_amount/100))
      when Promotion::TYPES['Buy [n] get 1 free'] then
        # Check for this is performed in "should_promotion_be_applied?"
        buy_n_item = self.order_line_items.detect { |i| i.item_id == promo.item_id }
        oli.quantity = buy_n_item.quantity / promo.discount_amount.to_i
        logger.info "ITEM QUANTITY #{oli.quantity}"
      else
        return
    end

    # Ensure discount can't be more than order total.
    if -oli.unit_price >= self.total
      oli.unit_price = -self.line_items_total(false)
    end
    
    if self.promotion_line_item.nil? && !self.order_line_items.include?(oli)
      self.order_line_items << oli
    end
    
    # Assign proper promotion
    self.promotion = promo
    unless self.new_record?
      Order.update(self.id, {:promotion_id => promo.id})
    end
  end

  def promotion_code
    if self.promotion
      return self.promotion.code
    else
      return nil
    end
  end

  # If affiliate_code is filled in, this tries to find 
  # a matching Affiliate and fill in affiliate_id.
  #
  # This links orders with affiliates.
  #
  # It also attempts to set promotion code.
  def affiliate_code=(code='')
    sanitized_code = code.strip unless code.blank?
    self.promotion_code = sanitized_code
    unless sanitized_code.blank?
      self.affiliate = Affiliate.find_by_code(sanitized_code)
    end
  end
  
  def affiliate_code
    if self.affiliate
      return self.affiliate.code
    else
      return nil
    end
  end
  
  # Adds a new order note from the edit page.
  # We display notes as read-only, so we only have to use a text field
  # instead of multiple records.
  def new_notes=(text)
    @new_notes = text
    return if @new_notes.blank?
    
    time = Time.now.strftime("%m-%d-%y %I:%M %p")
    new_note = "<p>#{@new_notes}<br/>"
    new_note << "<span class=\"info\">"
    new_note << "[#{time}]"
    new_note << "</span></p>"
    self.notes ||= ''
    write_attribute(:notes, self.notes + new_note)
    self.new_notes = nil
  end

  # Adds a product to our shopping cart
  def add_product(product, quantity=1)
    if quantity < 0
      remove_product(product, quantity.abs) and return
    end
    item = self.order_line_items.find(
      :first,
      :conditions => ["item_id = ?", product.id]
    )
    if item
      # Always set price, as it might have changed...
      item.update_attributes(
        :quantity => item.quantity += quantity,
        :price => product.price
      )
    else
      item = OrderLineItem.for_product(product)
      item.quantity = quantity
      item.order = self
      item.save
      self.order_line_items << item
    end
  end
  
  # Removes all quantities of product from our cart
  def remove_product(product, quantity=nil)
    item = self.order_line_items.find(
      :first,
      :conditions => ["item_id = ?", product.id]
    )
    if item
      if quantity.nil?
        quantity = item.quantity
      end
      if item.quantity > quantity then
        item.update_attribute(:quantity, item.quantity -= quantity)
      else
        self.order_line_items.delete(item)
      end
    end
    self.cleanup_promotion
  end
  
  # Compatibility for CART.
  # Determines if order has any items inside.
  def empty?
    self.order_line_items.size == 0
  end

  # Removes all items from order
  def empty!
    self.order_line_items.destroy_all
  end
  
  # Used to determine if a customer has passed the checkout stage
  # in the order process.
  def has_been_placed?
    return !(self.order_user.nil? || self.billing_address.nil? || self.account.nil?)
  end
  
  # Checks inventory of products, and removes them if
  # they're out of stock.
  #
  # Returns an array of items that have been removed.
  #
  def check_inventory
    removed_items = []
    self.order_line_items.each do |oli|
      # Find the item in the db, because oli.item is cached.
      db_item = Item.find_by_id(oli.item_id)
      next unless db_item # Skip promo items
      if oli.quantity > db_item.quantity
        removed_items << oli.name.clone
        self.order_line_items.delete(oli)
      end
    end
    return removed_items
  end
  
  # Shortcut to find order_line_item for a promotion that has been applied.
  def promotion_line_item
    if self.promotion
      return self.order_line_items.detect{|li| li.name == self.promotion.description}
    else
      return nil
    end
  end

  # Order status name
  def status
    code = OrderStatusCode.find(:first, :conditions => ["id = ?", self.order_status_code_id])
    code.name
  end

  # Total for the order, including shipping and tax.
  def total
    logger.debug "CALCULATING SHIPPING TOTAL"
    logger.debug "LINE ITEMS TOTAL: #{self.line_items_total}"
    logger.debug "SHIPPING COST: #{self.shipping_cost}"
    logger.debug "TAX COST: #{self.tax_cost}"
    (self.line_items_total + self.shipping_cost + self.tax_cost).round(2)
  end
  
  # How much an affiliate would make on this order
  def affiliate_earnings
    if self.is_payable_to_affiliate?
      earnings = self.line_items_total * (Affiliate.get_revenue_percentage.to_f/100)
    else
      earnings = 0
    end
    return earnings
  end
  
  # Only pay out for completed / shipped orders.
  def is_payable_to_affiliate?
    code_id = self.order_status_code_id
    return (code_id == 6 || code_id == 7)
  end
  
  # An order is complete if it has been paid for at any point.
  def is_complete?
    return (self.order_status_code_id >= 5)
  end
  
  # Defines if we can edit this order or not based on the status code
  def is_editable?
    case self.order_status_code_id
      when 1..5
        return true
    else
      return false
    end
  end
  
  # The tax of items if applied.
  #
  def tax_cost
    ((self.line_items_total) * (self.tax/100.0)).round(2)
  end

  def name
    "#{billing_address.first_name} #{billing_address.last_name}" rescue ''
  end
  

  # Sets line items from the product output table on the edit page.
  #
  # Deletes any line items with a quantity of 0.
  # Adds line items with a quantity > 0.
  #
  # This is called from update in our controllers.
  # What's passed looks something like this...
  #   @products = {'1' => {'quantity' => 2}, '2' => {'quantity' => 0}, etc}
  def line_items=(products)
    # Clear out all line items
    self.order_line_items.clear
    # Go through all products
    products.each do |id, product|
      quantity = product['quantity']
      if quantity.blank? then
        quantity = 0
      else
        quantity = Integer(quantity)
      end

      if (quantity > 0) then
        new_item = self.order_line_items.build
        logger.info("\n\nBUILDING NEW LINE ITEM\n")
        logger.info(new_item.inspect+"\n")
        new_item.quantity = quantity
        new_item.item_id = id
        new_item.unit_price = Item.find(:first, :conditions => "id = #{id}").price
        new_item.save
      end
    end
  end

  # Do we have a valid transaction id
  def contains_valid_transaction_id?()
    return (!self.auth_transaction_id.blank? && self.auth_transaction_id != 0)
  end

  # Determines if an order has a line item based on product id
  def has_line_item?(id)
    self.order_line_items.each do |item|
      return true if item.id == id
    end
    return false
  end

  # Gets quantity of a product if exists in current line items.
  def get_line_item_quantity(id)
    self.order_line_items.each do |item|
      return item.quantity if item.id == id
    end
    return 0
  end

  # Gets a subtotal for line items based on product id
  def get_line_item_total(id)
    self.order_line_items.each do |item|
      return item.total if item.id == id
    end
    return 0
  end

  # Grabs the total amount of all line items associated with this order
  def line_items_total(include_promo_items=true)
    total = 0
    promo_item = self.promotion_line_item
    for item in self.order_line_items
      if !include_promo_items
        next if item == promo_item
      end
      total += item.total
    end
    return total
  end

  # Calculates the weight of an order
  def weight
    weight = 0
    self.order_line_items.each do |item|
      weight += item.quantity * item.product.weight rescue 0
    end
    return weight
  end

  # Gets a flat shipping price for an order.
  # This is if we're not using live rate calculation usually
  #
  # A lot of people will want this overridden in their app
  def get_flat_shipping_price
    return Preference.find_by_name('store_handling_fee').value.to_f
  end

  # Gets all LIVE shipping prices for an order.
  #
  # Returns an array of OrderShippingTypes
  def get_shipping_prices
    prices = []
    # Pick the shipping address.
    address = self.shipping_address
    
    # Compare the country with the store home country.
    if address.country_id == Preference.find_by_name('store_home_country').value.to_i then
      shipping_types = OrderShippingType.get_domestic
    else 
      shipping_types = OrderShippingType.get_foreign
    end

    for type in shipping_types
      type.calculate_price(self.weight)
      prices << type
    end

    return prices

  end

  # Runs an order transaction.
  # Farms out the work to an Authorize.net or PayPal method
  # (or one of your devising).
  #
  # Should return TRUE if the process is successful.
  # Should return AN ERROR MESSAGE if not...
  #
  def run_transaction
    cc_processor = Order.get_cc_processor 
    if cc_processor == Preference::CC_PROCESSORS[0]
      run_transaction_authorize
    elsif cc_processor == Preference::CC_PROCESSORS[1]
      run_transaction_paypal_ipn
    else
      throw "The currently set preference for cc_processor is not recognized. You might want to add it to the code..."
    end
  end
 
  # Runs an order through Authorize.net
  #
  # Returns true 
  #
  def run_transaction_authorize
    ba = self.billing_address
  
    # For debugging with a test account...
    # ActiveMerchant::Billing::Base.mode = :test
    
    credit_card = ActiveMerchant::Billing::CreditCard.new(
      :number     => self.account.cc_number,
      :month      => self.account.expiration_month,
      :year       => self.account.expiration_year,
      :first_name => ba.first_name,
      :last_name  => ba.last_name
    )
    gateway = ActiveMerchant::Billing::AuthorizeNetGateway.new(
      :login      => Preference.find_by_name('cc_login').value,
      :password   => Preference.find_by_name('cc_pass').value,
      :ssl_strict => true,
      :test       => Preference.find_by_name('store_test_transactions').is_true?
    )
    address = {
      :address1 => ba.address,
      :city     => ba.city,
      :state    => ba.state,
      :zip      => ba.zip,
      :country  => ba.country.name
    }
    
    # AM requires it's purchaes in CENTS, so adjust accordingly.
    response = gateway.purchase(self.total.to_f*100, credit_card, {:address => address})
    # Save transaction id for later
    self.auth_transaction_id = response.authorization
        
    # Handle the response
    if response.success?
      logger.info("\n\nORDER TRANSACTION ID - #{self.auth_transaction_id}\n\n")
      # Set completed
      self.cleanup_successful
      # Send success message
      begin
        self.deliver_receipt
      rescue => e
        logger.error("FAILED TO SEND THE CONFIRM EMAIL: #{e}")
      end
      return true
    else
      # Log errors
      logger.error("\n\n[ERROR] FAILED ORDER \n")
      logger.error(response.inspect)
      logger.error(response.message)
      logger.error("\n\n")
      # Order failed - store transaction id
      self.cleanup_failed(response.message)
      # Send failed message
      begin
        self.deliver_failed
      rescue => e
        logger.error("FAILED TO SEND THE CONFIRM EMAIL: #{e}")
      end

      return response.message
    end
    
    return false
  end

  # PAYPAL IPN verification and execution -------------------------------------

  def matches_ipn?(notification, details)
    # Compare the information in the notification with the order.  The
    # Paypal::Notification object doesn't provide everything we want to verify
    # so we need to dig into the params[] array too.

    passed = true  #gives an inital clean slate

    # On occasion, an order will not be rounded to 2 decimal places
    if (self.total.to_f*100).round/100.00 != notification.gross.to_f
      passed = false 

      logger.error %Q\
        >>>The total passed back from PayPal doesn't match the
        total for invoice number #{notification.invoice}.
        Order total is #{((self.total.to_f*100).round/100.00).to_s} 
        and PayPal returned
        #{notification.gross.to_s}
      \
    end

    if details[:business] != Preference.find_by_name('cc_login').value
      passed = false
      logger.error %Q\
        >>>The business address passed back from PayPal is not 
        correct.  This likely means someone else ate your lunch."
      \
    end

    if Order.find_by_auth_transaction_id(details[:txn_id])
      passed = false
      logger.error %Q\
        >>>The authorization ID passed back from PayPal already
        exists in our database.  This would indicate that the
        user has used information from a previous transaction
        to spoof a new one."
      \
    end

    logger.error(">>>PAYPAL FRAUD DETECTED! Please investigate<<<") if !passed

    # PayPal also allows purchasers to add special instructions to sellers. We
    # should capture this and add it to the order notes

    if details[:memo] && details[:memo].length > 0
      self.new_notes = "CUSTOMER REMARKS: "+details[:memo]
    end

    if details[:address_street] && 
       details[:address_street] != self.shipping_address.address
      self.new_notes = %Q\
        The shipping address supplied by PayPal doesn't match
        the shipping address for this order. PayPal
        sent the following address:<br/>
        #{details[:address_street]}<br/>
        #{details[:address_city]}, #{details[:address_state]}<br/>
        #{details[:address_zip]}<br/>
        <b>Please contact the customer for clarification.<b>
      \
    end

    passed
  end

  def pass_ipn(auth_id)
    self.order_status_code_id = 5
    self.new_notes = "Order paid through PayPal.  Ready to ship."
    self.auth_transaction_id = auth_id
    # Set completed
    self.cleanup_successful
    # Send success message
    begin
      self.deliver_receipt
    rescue => e
      logger.error("FAILED TO SEND THE CONFIRM EMAIL: #{e}")
    end
    self.save
  end

  def fail_ipn
    #TODO - create a custom id for fraud.
    message = "FRAUD ALERT -- please investigate."
    self.order_status_code_id = 3
    self.new_notes = message
    self.cleanup_failed(message)
    # Send failed message
    begin
      self.deliver_failed 
    rescue => e
      logger.error("FAILED TO SEND THE CONFIRM EMAIL: #{e}")
    end
    self.save
  end
  
  # Do the cleanup for orders run through Paypal
  def run_transaction_paypal_ipn
    status_code = self.order_status_code.id
    # Under normal conditions, the paypal ipn should be confirmed already
    # but we can't count on that.  Assign a status of 4 (awaiting payment)
    # if the status is still 1 (cart)
    if status_code == 1
      new_order_code = OrderStatusCode.find_by_name("ON HOLD - AWAITING PAYMENT")
      self.order_status_code = new_order_code if new_order_code
      self.new_notes = "The order was processed at PayPal but not yet confirmed."
    end

    self.save
    self.order_status_code.id
  end

  # Cleans up a successful order
  def cleanup_successful
    # Decrement inventory for items...
    # Also driven by the inventory control preference from the admin  UI
    if Preference.find_by_name('store_use_inventory_control').is_true?
      self.order_line_items.each do |oli|
        begin
          oli.item.update_attribute('quantity', oli.item.quantity-oli.quantity)
        rescue
          # Do nothing...
          # Item might not exist because it's been deleted.
          # Smart in this case to do nothing.
        end
      end
    end
    
    new_order_code = OrderStatusCode.find_by_name("ORDERED - PAID - TO SHIP")
    self.order_status_code = new_order_code if new_order_code
    self.new_notes="Order completed."
    if Preference.find_by_name('cc_clear_after_order').is_true?
      self.account.clear_personal_information
    end
    self.save
  end

  # Cleans up a failed order
  def cleanup_failed(msg)
    new_order_code = OrderStatusCode.find_by_name("ON HOLD - PAYMENT FAILED")
    self.order_status_code = new_order_code if new_order_code
    self.new_notes="Order failed!<br/>#{msg}"
    self.save
  end


  # We define deliver_receipt here because ActionMailer can't seem to render
  # components inside a template.
  #
  # I'm getting around this by passing the text into the mailer.
  def deliver_receipt
    @content_node = ContentNode.find(:first, :conditions => ["name = ?", 'OrderReceipt'])
    if @content_node
      OrdersMailer.deliver_receipt(self, @content_node.content)
    else
      logger.error("The system didn't found a content node record named \"OrderReceipt\", this record " +
      "is used in the e-mail body. The e-mail deliver cannot proceed.")
    end
  end

  # If we're going to define deliver_receipt here, why not wrap deliver_failed as well?
  def deliver_failed
    OrdersMailer.deliver_failed(self)
  end

  # Is a discount present?
  def is_discounted?
    self.order_line_items.collect.each {|item| return true if item.unit_price < 0 }
    false
  end

end