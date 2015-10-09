require File.dirname(__FILE__) + '/../../test_helper'

class Admin::CustomersControllerTest < ActionController::TestCase
  fixtures :rights, :roles, :order_users, :orders, :users
  
  def setup
    login_as :admin
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'list'
  end

  # Test the customers action.
  def test_list
    get :list
    assert_response :success
    assert_template 'list'
    assert_equal assigns(:title), "Customer List"
    assert_not_nil assigns(:customers)
  end

  # Test if we can download an user list.
  def test_list_csv
    get :index, :format => 'csv'
    assert_response_csv
  end

end