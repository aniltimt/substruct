# Deals with affiliate order tracking
class AffiliatesController < ApplicationController
  layout 'affiliate'
  before_filter :ssl_required

	# Check permissions for everything on within side.
  before_filter :login_required,
	  :except => [:login, :sign_up]
	before_filter :get_affiliate, 
	  :only => [
	    :account, :earnings, :index, :terms_conditions, :promotion_tools,
	    :orders, :payments
	  ]

  def index
    earnings()
    render :action => 'earnings' and return
  end

  def login
    @title = "Affiliate Login"
    if request.post?
      if @affiliate = Affiliate.authenticate(params[:email_address], params[:code])
        session[:affiliate] = @affiliate.id
        redirect_back_or_default :action => 'index'
      else
        flash.now[:notice]  = "Login unsuccessful"
      end
    end
  end
  
  def logout
    session[:affiliate] = nil
    flash[:notice] = "You've been logged out as an affiliate."
    redirect_to :action => 'login' and return
  end
  
  def sign_up
    @title = "Affiliate application"
    @affiliate = Affiliate.new(:code => Affiliate.generate_code)
    if request.post?
      @affiliate.attributes = params[:affiliate]
      if @affiliate.save
        flash[:notice] = "Your affiliate application was received successfully."
        redirect_to '/' and return
      else
        flash[:notice] = "There was a problem processing your application.<br/>Please see the fields below."
        render and return
      end
    end
  end
  
  # Account details
  # Can change email or password from this.
  def account
    @title = "Account Details"
    # Update account details
    if request.post?
      if @affiliate.update_attributes(params[:affiliate])
        flash.now[:notice] = "Account details saved."
      else
        flash.now[:notice] = "There was a problem saving your account."
      end
    end
  end

  # Displays earnings made by affiliate.
  def earnings
    @title = "Your Earnings"
    @earnings = @affiliate.get_earnings()
  end
  
  def payments
    @title = "Payments made to you"
    @payments = @affiliate.payments.find(:all, :order => "id DESC")
  end
  
  # Screen to show terms / conditions of your affiliate program.
  # Exists as a ContentNode snippet for easy editing by site owners.
  def terms_conditions
    @title = "Terms and Conditions"
  end
  
  # Screen to provide banners, links, etc.
  # Useful for affiliates to copy / paste.
  def promotion_tools
    @title = "Promotion Tools"
  end
  
  # Shows orders for a date range for affiliate
  def orders
    @date = Date.parse(params[:date]).beginning_of_month if params[:date]
    @date ||= Date.today.beginning_of_month
    @title = "Earnings for #{@date.strftime('%B %Y')}"
    @orders = @affiliate.orders.find(
      :all,
      :conditions => [
        "created_on BETWEEN DATE(?) AND DATE(?)", 
        @date, @date.end_of_month
      ]
    )
  end
	
	# PRIVATE METHODS ===========================================================
	private
    # Makes sure affiliate is logged in before accessing stuff here.
    def login_required
      return true if session[:affiliate]

      # store current location so that we can 
      # come back after the user logged in
      store_location
      redirect_to :action =>"login" and return false 
    end
    
    def get_affiliate
      @affiliate = Affiliate.find(session[:affiliate])
    end
	
    # store current uri in  the session.
    # we can return to this location by calling return_location
    def store_location
      session[:return_to] = request.request_uri
    end
	
	  # Move to the last store_location call or to the passed default one
    def redirect_back_or_default(default)
      if session[:return_to].nil?
        redirect_to default
      else
        redirect_to session[:return_to]
        session[:return_to] = nil
      end
    end
	
end
