require File.dirname(__FILE__) + '/../test_helper'

class VariationTest < ActiveSupport::TestCase
  # If the model was inherited from another model, the fixtures must be the
  # base model, as it will be used as the table name.
  fixtures :items

  def setup
    @v = items(:small_stuff)
  end


  # Test if the fixtures are of the proper type.
  def test_item_should_be_of_proper_type
    assert_kind_of Variation, items(:red_lightsaber)
    assert_kind_of Variation, items(:blue_lightsaber)
    assert_kind_of Variation, items(:green_lightsaber)
    assert_kind_of Variation, items(:grey_coat)
    assert_kind_of Variation, items(:beige_coat)
    assert_kind_of Variation, items(:small_stuff)
  end


  # Test if an orphaned variation will NOT be saved.
  # Don't assign the variation to anything and try to save it.
  def test_should_can_save_orphan
    @v = Variation.new
    @v.code = "BIG_STUFF"
    @v.name = "Big"
    @v.price = 5.75
    @v.quantity = 500

    assert @v.save!
  end


  # Test if a valid variation can be assigned and saved with success.
  def test_should_assign_and_save_variation
    # Load a product.
    a_product = items(:the_stuff)
    assert_nothing_raised {
      Product.find(a_product.id)
    }

    # Create a variation.
    @v = Variation.new
    @v.code = "BIG_STUFF"
    @v.name = "Big"
    @v.price = 5.75
    @v.quantity = 500

    # Assign the variation to its respective product and save the variation.  
    assert a_product.variations << @v
    assert @v.save
    
    # Verify if a default date is beeing assigned to date_available.
    assert_equal @v.date_available, Date.today
  end


  # Test if a variation can be found with success.
  def test_should_find_variation
    @v_id = items(:small_stuff).id
    assert_nothing_raised {
      Variation.find(@v_id)
    }
  end


  # Test if a variation can be updated and if the product will be updated too.
  def test_should_update_variation_and_product
    
    assert @v.update_attributes(:name => 'Very Small')
    
    # Load the variation's product.
    a_product = @v.product
    variation_quantity = a_product.variation_quantity
    assert @v.update_attributes(:quantity => @v.quantity + 2)
    assert_equal a_product.variation_quantity, variation_quantity + 2 
  end


  # Test if a variation can be destroyed and if its product will know about that.
  def test_should_destroy_variation
    variations_counter = @v.product.variations.count
    @v.destroy
    assert_raise(ActiveRecord::RecordNotFound) {
      Variation.find(@v.id)
    }
    assert_equal @v.product.variations.count, variations_counter - 1 
  end


  # Test if an invalid variation really will NOT be created.
  def test_unique_code
    @v = Variation.new
    @v.product = items(:the_stuff)

    # Choosing an already taken variation code.
    @v.code = "STUFF"
    assert !@v.valid?, @v.inspect
    assert @v.errors.invalid?(:code)
    # A variation must have an unique code.
    assert_equal "has already been taken", @v.errors.on(:code)

    assert !@v.save
  end


  # Test if the variation images points to product images as variations can't
  # have their own images.
  def test_should_point_its_images_to_product_images
    assert_equal @v.images, @v.product.images
  end


  # Test if the variation name is concatenated with the product name.
  def test_should_concatenate_product_name
    assert_equal @v.name, "#{@v.product.name} - #{@v.short_name}" 
  end

  def test_nil_price_uses_base
    assert @v.update_attribute(:price, nil)
    assert_equal @v.product.price, @v.price
  end
  
  def test_zero_price_uses_base
    assert @v.update_attribute(:price, 0)
    assert_equal @v.product.price, @v.price
  end
  
  def test_nil_price_no_product
    @v.stubs(:product).returns(nil)
    assert @v.update_attribute(:price, nil)
    assert_equal 0.0, @v.price
  end
  
  # We use 0 or nil to determine that the price of a variation
  # should be the same as the base product.
  def test_same_price_as_base_doesnt_save
    @v.price = @v.product.price
    assert @v.save
    assert_nil @v.read_attribute('price')
  end
  
  def test_clean_code_variation
    # Load a product.
    a_product = items(:the_stuff)

    # Create a variation.
    v = a_product.variations.new(
      :name => 'XXL',
      :price => 100.00,
      :quantity => 10
    )

    assert v.save
    assert_equal "STUFF-XXL", v.code
  end

end
