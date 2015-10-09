# This is the base model for Product and ProductVariation.
#
#
class Item < ActiveRecord::Base
  has_many :order_line_items
  has_many :wishlist_items, :dependent => :destroy
  validates_presence_of :name, :code
  validates_uniqueness_of :code
  
  #############################################################################
  # CALLBACKS
  #############################################################################
  
  # DB complains if there's not a date available set.
  # This is a cheap fix.
  before_save :set_date_available
  def set_date_available
    self.date_available = Date.today if !self.date_available
  end

  # Inserts code from product name if not entered.
  # Makes code safe for URL usage.
  before_validation :clean_code
  def clean_code
    self.code = self.name.clone if self.code.blank?
    self.code.upcase!
    self.code = self.code.gsub(/[^[:alnum:]]/,'-').gsub(/-{2,}/,'-')
    self.code = self.code.gsub(/^[-]/,'').gsub(/[-]$/,'')
    self.code.strip!

    return true
	end

  #############################################################################
  # CLASS METHODS
  #############################################################################


  #############################################################################
  # INSTANCE METHODS
  #############################################################################

  # Name output for product suggestion JS
  # 
  def suggestion_name
    "#{self.code}: #{self.name}"
  end
  
end
