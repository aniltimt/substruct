class OrderStatusCode < ActiveRecord::Base
  has_many :orders
end
