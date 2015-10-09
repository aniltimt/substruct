require 'rubygems'
require 'test/unit'
require File.expand_path('../../lib/mini_magick', __FILE__)

#MiniMagick.processor = :gm

class ImageTest < Test::Unit::TestCase
  include MiniMagick

  CURRENT_DIR = File.dirname(File.expand_path(__FILE__)) + "/"

  SIMPLE_IMAGE_PATH = CURRENT_DIR + "simple.gif"
  MINUS_IMAGE_PATH = CURRENT_DIR + "simple-minus.gif"
  TIFF_IMAGE_PATH = CURRENT_DIR + "leaves.tiff"
  NOT_AN_IMAGE_PATH = CURRENT_DIR + "not_an_image.php"
  GIF_WITH_JPG_EXT = CURRENT_DIR + "actually_a_gif.jpg"
  EXIF_IMAGE_PATH = CURRENT_DIR + "trogdor.jpg"
  ORIENTED_IMAGE_PATH = CURRENT_DIR + "oliver.jpg"
  ANIMATION_PATH = CURRENT_DIR + "animation.gif"

  def test_image_from_blob
    File.open(SIMPLE_IMAGE_PATH, "rb") do |f|
      image = Image.from_blob(f.read)
      image.destroy!
    end
  end

  def test_image_from_file
    image = Image.from_file(SIMPLE_IMAGE_PATH)
    image.destroy!
  end

  def test_image_new
    image = Image.new(SIMPLE_IMAGE_PATH)
    image.destroy!
  end

  def test_image_write
    output_path = "output.gif"
    begin
      image = Image.new(SIMPLE_IMAGE_PATH)
      image.write output_path

      assert File.exists?(output_path)
    ensure
      File.delete output_path
    end
    image.destroy!
  end

  def test_not_an_image
    assert_raise(MiniMagick::Invalid) do
      image = Image.new(NOT_AN_IMAGE_PATH)
      image.destroy!
    end
  end

  def test_image_meta_info
    image = Image.new(SIMPLE_IMAGE_PATH)
    assert_equal 150, image[:width]
    assert_equal 55, image[:height]
    assert_equal [150, 55], image[:dimensions]
    assert_match(/^gif$/i, image[:format])
    image.destroy!
  end

  def test_tiff
    image = Image.new(TIFF_IMAGE_PATH)
    assert_equal "tiff", image[:format].downcase
    assert_equal 50, image[:width]
    assert_equal 41, image[:height]
    image.destroy!
  end

  # def test_animation_pages
  #   image = Image.from_file(ANIMATION_PATH)
  #   image.format "png", 0
  #   assert_equal "png", image[:format].downcase
  #   image.destroy!
  # end

  # def test_animation_size
  #   image = Image.from_file(ANIMATION_PATH)
  #   assert_equal image[:size], 76631
  #   image.destroy!
  # end

  def test_gif_with_jpg_format
    image = Image.new(GIF_WITH_JPG_EXT)
    assert_equal "gif", image[:format].downcase
    image.destroy!
  end

  def test_image_resize
    image = Image.from_file(SIMPLE_IMAGE_PATH)
    image.resize "20x30!"

    assert_equal 20, image[:width]
    assert_equal 30, image[:height]
    assert_match(/^gif$/i, image[:format])
    image.destroy!
  end

  def test_image_resize_with_minimum
    image = Image.from_file(SIMPLE_IMAGE_PATH)
    original_width, original_height = image[:width], image[:height]
    image.resize "#{original_width + 10}x#{original_height + 10}>"

    assert_equal original_width, image[:width]
    assert_equal original_height, image[:height]
    image.destroy!
  end

  def test_image_combine_options_resize_blur
    image = Image.from_file(SIMPLE_IMAGE_PATH)
    image.combine_options do |c|
      c.resize "20x30!"
      c.blur 50
    end

    assert_equal 20, image[:width]
    assert_equal 30, image[:height]
    assert_match(/^gif$/i, image[:format])
    image.destroy!
  end
  
  def test_image_combine_options_with_filename_with_minusses_in_it
    image = Image.from_file(SIMPLE_IMAGE_PATH)
    assert_nothing_raised do
      image.combine_options do |c|
        c.draw "image Over 0,0 10,10 '#{MINUS_IMAGE_PATH}'"
      end
    end
    image.destroy!
  end

  def test_exif
    image = Image.from_file(EXIF_IMAGE_PATH)
    assert_equal('0220', image["exif:ExifVersion"])
    image = Image.from_file(SIMPLE_IMAGE_PATH)
    assert_equal('', image["EXIF:ExifVersion"])
    image.destroy!
  end
  
  # The test here isn't really to check to see if 
  # the auto-orient function of ImageMagick works,
  # but to make sure we can send dashed commands.
  def test_auto_rotate
    image = Image.from_file(EXIF_IMAGE_PATH)
    image.auto_orient
    image.destroy!
  end

  def test_original_at
    image = Image.from_file(EXIF_IMAGE_PATH)
    assert_equal(Time.local('2005', '2', '23', '23', '17', '24'), image[:original_at])
    image = Image.from_file(SIMPLE_IMAGE_PATH)
    assert_nil(image[:original_at])
    image.destroy!
  end

  def test_tempfile_at_path
    image = Image.from_file(TIFF_IMAGE_PATH)
    assert_equal image.path, image.tempfile.path
    image.destroy!
  end

  def test_tempfile_at_path_after_format
    image = Image.from_file(TIFF_IMAGE_PATH)
    image.format('png')
    assert_equal image.path, image.tempfile.path
    image.destroy!
  end

  def test_previous_tempfile_deleted_after_format
    image = Image.from_file(TIFF_IMAGE_PATH)
    before = image.path.dup
    image.format('png')
    assert !File.exist?(before)
    image.destroy!
  end
  
  def test_bad_method_bug
    image = Image.from_file(TIFF_IMAGE_PATH)
    begin
      image.to_blog
    rescue NoMethodError
      assert true
    end
    image.to_blob
    assert true #we made it this far without error
    image.destroy!
  end

  # def test_mini_magick_error_when_referencing_not_existing_page
  #   image = Image.from_file(ANIMATION_PATH)
  #   image.format('png')
  #   assert_equal image[:format], 'PNG'
  #   image.destroy!
  # end
end
