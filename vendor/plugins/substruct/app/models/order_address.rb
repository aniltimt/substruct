class OrderAddress < ActiveRecord::Base
  # Association
  has_one :order
  belongs_to :order_user
  belongs_to :country
  # Validation
  validates_presence_of :order_user_id, :country_id
  validates_presence_of :zip, :message => "#{ERROR_EMPTY} If you live in a country that doesn't have postal codes please enter '00000'."
  validates_presence_of :telephone, :message => ERROR_EMPTY
  validates_presence_of :first_name, :message => ERROR_EMPTY
  validates_presence_of :last_name, :message => ERROR_EMPTY
  validates_presence_of :address, :message => ERROR_EMPTY
  # Require city / state if USA
  validates_presence_of :city, :state,
      :if => Proc.new { |oa| oa.country && oa.country.name == 'United States of America' }

  validates_length_of :first_name, :maximum => 50
  validates_length_of :last_name, :maximum => 50
  validates_length_of :address, :maximum => 255

  US_STATES = %\AK AR AZ CT FL HI IL KY MD MN MT NE NM OH PA SC TX VI WI AL CA DC GA IA IN LA ME  	MO NC NH NV OK PR SD UT VT WV CO DE GU ID KS MA MI MS ND NJ NY OR RI TN VA WA WY\.split( /\W+/ )

  #Makes sure validation address doesn't allow PO Box or variants
  def validate
    invalid_strings = [
      'PO BOX', 'P.O. BOX', 'P.O BOX', 'PO. BOX', 'POBOX',
      'P.OBOX', 'P.O.BOX', 'PO.BOX', 'P.BOX', 'PBOX', 'AFO',
      'A.F.O.', 'APO', 'A.P.O.'
    ]
    cap_address = self.address.upcase()
    invalid_strings.each do |string|
      if cap_address.include?(string) then
        errors.add(:address, "Sorry, we don't ship to P.O. boxes")
      end
    end
    if self.country && self.country.name == "United States of America"
      unless zip.blank?
        unless zip =~ /^\d{5}/
          errors.add(:zip, "Please enter a valid zip.")
        end
      end
      self.state = self.state.upcase
      errors.add(:state, "Please use a US state abbreviation") unless US_STATES.include?(self.state)
    end
  end

  # Finds the shipping address for a given OrderUser
  def self.find_shipping_address_for_user(user)
    find(:first,
    :conditions => ["order_user_id = ? AND is_shipping = 1", user.id])
  end

  def name
    "#{self.first_name} #{self.last_name}"
  end
end
