require File.dirname(__FILE__) + '/../test_helper'

class AccountsControllerTest < ActionController::TestCase
  fixtures :rights, :roles, :users

  def setup
    @user = users(:c_norris)
  end

  # Test the login action.
  def test_login_get
    get :login
    assert_response :success
    assert_template 'login'
  end
    
  def test_login_post
    post :login, :user_login => "c_norris", :user_password => "admin"
    # If loged in we should be redirected to welcome. 
    assert_response :redirect
    assert_redirected_to :action => :welcome

    # Assert the user id is in the session.
    assert_equal session[:user], @user.id
  end

  # Test the login action with a wrong password.
  def test_login_fail    
    post :login, :user_login => "c_norris", :user_password => "wrong_password"
    assert_response :success
    assert_template 'login'
    assert_select "div#message", :text => /Login unsuccessful/
    assert_equal session[:user], nil
  end

  def test_logout
    login_as(:c_norris)
    post :logout
    assert_response :success
    assert_template 'logout'
    assert_nil session[:user]
  end

end
