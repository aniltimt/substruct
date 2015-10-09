require File.dirname(__FILE__) + '/../test_helper'

class AffiliatesControllerTest < ActionController::TestCase
  fixtures :affiliates, :order_users, :orders, :items

  def setup
    @jm = affiliates(:joes_marketing)
  end
  
  def login_affiliate
    @request.session[:affiliate] = @jm.id
  end

  def test_sign_up
    get :sign_up
    assert_response :success
    assert_layout 'affiliate'
    assert_template 'sign_up'
  end
  
  def test_sign_up_success
    assert_difference 'Affiliate.count' do
      post :sign_up,
        :affiliate => {
          :code => Affiliate.generate_code,
          :email_address => 'youngbob@extrarainbow.com'
        }
    end
    assert_redirected_to '/'
    assert !flash[:notice].blank?
    assert !Affiliate.find(:last).is_enabled?
  end

  def test_login
    get :login
    assert_response :success
    assert_layout 'affiliate'
  end

  def test_login_success
    assert_nil @request.session[:affiliate]
    post :login, :email_address => @jm.email_address, :code => @jm.code
    assert_redirected_to :action => 'index'
    assert_equal @jm.id, session[:affiliate]
  end
  
  def test_login_fail
    post :login, :email_address => '', :code => @jm.code
    assert_response :success
    assert_equal "Login unsuccessful", flash.now[:notice]
    assert_nil session[:affiliate]
  end
  
  def test_logout
    login_affiliate()
    post :logout
    assert_redirected_to :action => 'login'
    assert_equal "You've been logged out as an affiliate.", flash[:notice]
  end
  
  def test_account_get
    login_affiliate()
    get :account
    assert_response :success
    assert_layout 'affiliate'
  end
  
  def test_account_post
    login_affiliate()
    new_email_address = 'mynewemail@gmail.com'
    post :account,
      :affiliate => {
        :email_address => new_email_address
      }
    assert_response :success
    assert_equal new_email_address, @jm.reload.email_address
  end
  
  def test_index
    login_affiliate()
    get :index
    assert_response :success
    assert_layout 'affiliate'
    assert_template 'earnings'
  end
  
  def test_earnings
    login_affiliate()
    get :earnings
    assert_response :success
    assert_layout 'affiliate'
  end
  
  def test_payments
    login_affiliate()
    get :payments
    assert_response :success
    assert_layout 'affiliate'
    assert_template 'payments'
    assert_equal @jm.payments.count, assigns(:payments).size
  end
  
  def test_terms_conditions
    login_affiliate()
    get :terms_conditions
    assert_response :success
  end
  
  def test_promotion_tools
    login_affiliate()
    get :promotion_tools
    assert_response :success
  end
  
  def test_orders_with_date
    login_affiliate()
    d = Date.today.beginning_of_month - 1.month
    get :orders, :date => d.to_s
    assert_equal assigns(:date), d
    assert_response :success
    assert assigns(:orders).size > 0
  end
  
  def test_orders_with_no_date
    login_affiliate()
    d = Date.today.beginning_of_month
    get :orders
    assert_response :success
    assert_equal assigns(:date), d
    assert assigns(:orders).size > 0
  end
end