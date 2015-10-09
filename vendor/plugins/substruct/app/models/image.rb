# Represents an image
#
class Image < UserUpload

  has_many :product_images, :dependent => :destroy
  has_many :products, :through => :product_images
  
  MAX_SIZE = 10.megabyte
  
  SIZES = {
    :thumb => '75x75>', 
    :small => '200x200'
  }

  has_attachment :content_type => :image,
                 :storage => :file_system,
                 :max_size => MAX_SIZE,
                 :thumbnails => SIZES,
                 :path_prefix => 'public/system/'

  validates_as_attachment

end
