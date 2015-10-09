require File.dirname(__FILE__) + '/../../test_helper'

class Admin::FilesControllerTest < ActionController::TestCase
  fixtures :rights, :roles, :users
  fixtures :user_uploads

  def setup
    login_as :admin
  end

  # Test the index action.
  def test_index_success
    get :index
    assert_response :success
    assert_template 'index'
    assert_equal assigns(:title), "User uploaded files"
    assert_not_nil assigns(:files)
  end


  # Test the list action passing keys.
  def test_index_images
    get :index, :key => "Image"
    assert_response :success
    assert_template 'index'
    assert_equal assigns(:title), "User uploaded files - #{assigns(:viewing_by).pluralize}"
    assert_not_nil assigns(:files)
  end

  def test_index_assets
    get :index, :key => "Asset"
    assert_response :success
    assert_template 'index'
    assert_equal assigns(:title), "User uploaded files - #{assigns(:viewing_by).pluralize}"
    assert_not_nil assigns(:files)
  end

  def test_index_sorted_by_name
    get :index, :sort => "name"
    assert_response :success
    assert_template 'index'
    assert_equal assigns(:title), "User uploaded files"
    assert assigns(:files).size > 1
    # Ensure order of files
    last_filename = ''
    assigns(:files).each do |f|
      assert f.filename > last_filename
      last_filename = f.filename
    end
  end
  

  def test_destroy_success
    an_user_upload = user_uploads(:lightsaber_blue_upload)

    # Post to it a content_node.
    post :destroy, :id => an_user_upload.id

    assert_raise(ActiveRecord::RecordNotFound) {
      UserUpload.find(an_user_upload.id)
    }
  end

  def test_image_library
    get :image_library
    assert_response :success
    assert_layout 'admin_modal'
  end
  
  def test_cant_get_upload
    get :upload
    assert_response :success
    assert_equal "Uploading files can happen from a HTTP post only.", @response.body
  end

  def test_upload_success
    lightsabers_image = fixture_file_upload("/files/lightsabers.jpg", 'image/jpeg')

    post(
      :upload,
      :file => [
        { :file_data_temp => "", :file_data => lightsabers_image }, 
        { :file_data_temp => "", :file_data => "" }
      ]
    )

    assert_redirected_to :action => :index
    user_upload = UserUpload.find_by_filename('lightsabers.jpg')
    assert_kind_of UserUpload, user_upload

    # We must erase the record and its files by hand, just calling destroy.
    assert user_upload.destroy
  end
  
  def test_upload_succes_modal
    lightsabers_image = fixture_file_upload("/files/lightsabers.jpg", 'image/jpeg')

    post(
      :upload,
      :modal => true,
      :file => [
        { :file_data_temp => "", :file_data => lightsabers_image }, 
        { :file_data_temp => "", :file_data => "" }
      ]
    )

    assert_redirected_to :action => :image_library
    user_upload = UserUpload.find_by_filename('lightsabers.jpg')
    assert_kind_of UserUpload, user_upload

    # We must erase the record and its files by hand, just calling destroy.
    assert user_upload.destroy
  end

end
