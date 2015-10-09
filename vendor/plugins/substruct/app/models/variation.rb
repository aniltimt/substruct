# Holds information about how the product varies.
#
class Variation < Item
  belongs_to :product
  
  #############################################################################
  # CALLBACKS
  #############################################################################
  
  after_save :update_parent_quantity
  def update_parent_quantity
    if self.product
      self.product.update_attribute(
        'variation_quantity', 
        self.product.variations.sum('quantity')
      )
    end
  end
  
  before_save :check_base_product_price
  def check_base_product_price
    if self.product && self.product.price == self[:price]
      self.price = nil
    end
    return true
  end
  
  # Override of item.rb
  def clean_code
    if self.code.blank? && self.product && !self.product.code.blank?
      self.code = "#{self.product.code}-#{self.short_name}"
    elsif self.code.blank?
      self.code = self.name.clone
    end
    self.code.upcase!
    self.code = self.code.gsub(/[^[:alnum:]]/,'-').gsub(/-{2,}/,'-')
    self.code = self.code.gsub(/^[-]/,'').gsub(/[-]$/,'')
    self.code.strip!

    return true
	end
  
  #############################################################################
  # CLASS METHODS
  #############################################################################
  
  # References parent product images collection.
  #
  def images
    self.product.images
  end

  # Display name...includes product name as well
  def name
    if self.product
      return "#{self.product.name} - #{self[:name]}"
    else
      return self[:name]
    end
  end
  
  def short_name
    self[:name]
  end
  
  # Setting price on a variation to nil or 0 assumes we want to use
  # the base product's price. This allows us to set price for multiple variations
  # in one easy place.
  def price
    price = 0.0
    if self.product && (self[:price].nil? || self[:price] == 0)
      price = self.product.price
    else
      price = self[:price]
    end
    return price || 0.0
  end
  
end