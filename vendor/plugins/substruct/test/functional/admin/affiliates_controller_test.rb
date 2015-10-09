require File.dirname(__FILE__) + '/../../test_helper'

class Admin::AffiliatesControllerTest < ActionController::TestCase
  fixtures :all
  
  def setup
    login_as :admin
    @affil = affiliates(:joes_marketing)
  end
  
  def assert_no_affiliate
    assert_redirected_to :action => 'list'
    assert flash[:notice] = "Sorry, that affiliate code is invalid"
  end
  
  def test_list
    get :list
    assert_response :success
  end
  
  def test_new
    get :new
    assert_response :success
  end

  # CREATE
  
  def test_cant_get_create
    assert_cant_get(:create, {:action => :index})
  end
  
  def test_create_success
    assert_difference "Affiliate.count" do
      post :create,
        :affiliate => {
          :email_address => 'joe_blow@gmail.com',
          :code => 'abcdef',
          :first_name => 'joe',
          :last_name => 'blow'
        }
      assert_redirected_to :action => 'list'
    end
  end
  
  def test_create_fail
    assert_no_difference "Affiliate.count" do
      post :create,
        :affiliate => {}
      assert_response :success
      assert_template 'new'
    end
  end
  
  # UPDATE
  
  def test_cant_get_update
    assert_cant_get(:update, {:action => :index})
  end
  
  def test_update_success
    new_first = 'joe mama'
    new_last = 'bamalama'
    post :update,
      :affiliate => {
        :first_name => new_first,
        :last_name => new_last,
        :code => @affil.code,
        :address => @affil.address,
        :city => @affil.city,
        :state => @affil.state,
        :zip => @affil.zip,
        :telephone => @affil.telephone
      },
      :id => @affil.id
    assert_response :success
    assert_template 'edit'
    assert !flash[:notice].blank?
    
    @affil.reload
    assert_equal new_first, @affil.first_name
    assert_equal new_last, @affil.last_name
  end
  
  # DESTROY
  
  def test_cant_get_destroy
    assert_cant_get(:destroy, {:action => :index})
  end
  
  def test_destroy_success
    assert_difference "Affiliate.count", -1 do
      post :destroy, :id => @affil.id
    end
  end
  
  def test_destroy_invalid
    assert_no_difference "Affiliate.count" do
      post :destroy, :id => 'fake_affil_id'
      assert_no_affiliate
    end
  end
  
  # SHOW ORDERS 
  
  def test_orders
    get :orders, :id => @affil.id
    assert_response :success
  end
  
  def test_show_orders_invalid
    get :orders, :id => 'invalid_id'
    assert_no_affiliate
  end
  
  def test_earnings
    get :earnings, :id => @affil.id
    assert_response :success
  end
  
  # PAYMENTS ==================================================================
  
  def test_payments_for_affiliate
    get :payments_for_affiliate, :id => @affil.id
    assert_response :success
    assert assigns(:payments).size > 0
  end
  
  def test_show_payment
    get :show_payment, :id => affiliate_payments(:joe_today).id
    assert_response :success
  end
  
  def test_show_payment_bad_id
    get :show_payment, :id => 'abcdef'
    assert_redirected_to :action => 'list'
    assert !flash[:notice].blank?
  end
  
  def test_payment_list
    get :list_payments
    assert_response :success
    assert assigns(:payments).size > 0
  end
  
  def test_payment_list_with_date
    d = affiliate_payments(:joe_today).created_at.to_date
    get :list_payments, :date => d.to_s(:db)
    assert_response :success
    assert assigns(:payments).size > 0
  end
  
  def test_payment_list_with_date_hash
    d = affiliate_payments(:joe_today).created_at.to_date
    get :list_payments, :date => {
      :month => '2', :day => '1', :year => '2010'
    }
    assert_response :success
    assert_kind_of Date, assigns(:date)
  end
  
  def test_payment_list_with_date_no_payments
    get :list_payments, :date => (Date.today-1.month).to_date.to_s(:db)
    assert_response :success
    assert_equal 0, assigns(:payments).size
  end
  
  def test_payment_list_csv
    get :list_payments, :format => 'csv'
    assert_response_csv
  end
  
  def test_destroy_payment
    assert_difference 'AffiliatePayment.count', -1 do
      post :destroy_payment, :id => affiliate_payments(:joe_today).id
      assert_redirected_to :action => 'payments_for_affiliate', :id => @affil.id
      assert !flash[:notice].blank?
    end
  end
  
  def test_make_payments_get
    get :make_payments
    assert_response :success
    assert assigns(:payments).size > 0
    assigns(:payments).each do |p|
      assert p.new_record?
    end
  end
  
  def test_make_payments_post
    expected_notes = 'Sample notes assigned to each order'
    assert_difference 'AffiliatePayment.count', Affiliate.find_unpaid.size do
      post :make_payments, :notes => expected_notes
      assigns(:payments).each do |p|
        assert !p.new_record?
        assert_equal expected_notes, p.notes
      end
      assert_redirected_to :action => 'list_payments', :date => Date.today.to_s(:db)
      assert !flash[:notice].blank?
    end
  end
  
end