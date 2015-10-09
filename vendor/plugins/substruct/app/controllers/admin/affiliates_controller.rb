class Admin::AffiliatesController < Admin::BaseController
  verify :method => :post, 
    :only => [ :create, :update, :destroy], 
    :redirect_to => {:action => :index}
  
  before_filter :get_affiliate,
    :only => [
      :edit, :update, :destroy, :orders, :earnings, 
      :payments_for_affiliate
    ]
  
  before_filter :get_payment,
    :only => [:show_payment, :destroy_payment]
  
  def index
    list
    render :action => 'list'
  end

  def list
    @title = "Affiliate List"
    @affiliates = Affiliate.find(
      :all, :order => 'created_at DESC'
    )
  end

  def new
    @title = "Creating New Affiliate"
    @affiliate = Affiliate.new
  end

  def create
    @title = "Creating Affiliate"
    @affiliate = Affiliate.new(params[:affiliate])
    if @affiliate.save
      flash[:notice] = 'Affiliate was successfully created.'
      redirect_to :action => 'list'
    else
      render :action => 'new'
    end
  end

  def edit
    @title = "Editing Affiliate"
  end

  def update
    if @affiliate.update_attributes(params[:affiliate])
      flash[:notice] = 'Affiliate was successfully updated.'
    end
    render :action => 'edit'
  end

  # Deletes an affiliate
  def destroy
    @affiliate.destroy
    flash[:notice] = "Affiliate deleted successfully"
    redirect_to :action => 'list'
  end

  # Displays earnings made by affiliate.
  def earnings
    @title = "Earnings for #{@affiliate.name}"
    @earnings = @affiliate.get_earnings()
  end
  
  # Shows all orders in a month for affiliate.
  # Defaults to current month if no date passed
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

  # PAYMENTS ==================================================================

  def list_payments
    d = params[:date]
    if d
      if d[:year]
        @date = Time.mktime(d[:year], d[:month], d[:day], 1).to_date
      else
        @date = Date.parse(d)
      end
      conds = ["DATE(created_at) = DATE(?)", @date]
      @title = "Affiliate Payments - #{@date.strftime('%m/%d/%Y')}"
    else
      conds = []
      @title = "All Affiliate Payments"
    end
    respond_to do |format|
      format.html do
        @payments = AffiliatePayment.paginate(
          :order => 'created_at DESC',
          :conditions => conds,
          :page => params[:page],
          :per_page => 30
        )
      end
      format.csv do
        send_data(
          AffiliatePayment.get_csv_for(
            AffiliatePayment.find(:all, :conditions => conds)
          ),
          :filename => "AffiliatePayments.csv",
          :type => 'text/csv'
        ) and return
      end
    end
  end
  
  def make_payments
    @payments = AffiliatePayment.new_for_all_unpaid
    if request.get?
      if @payments.size > 0
        @title = "Create payments for these affiliates?"
      else
        @title = "No payments to create"
      end
    elsif request.post?
      @title = "Affiliate Payments Recorded"
      @payments.each do |p| 
        p.notes = params[:notes]
        p.save!
      end
      flash[:notice] = "#{@payments.size} payment(s) created"
      redirect_to :action => 'list_payments', :date => Date.today.to_s(:db) and return
    end
  end

  # Showing payments for a single affiliate
  def payments_for_affiliate
    @title = "Payments made to #{@affiliate.name}"
    @payments = @affiliate.payments.find(:all, :order => "id DESC")
  end

  # Shows a single payment
  def show_payment
    @title = "Payment Detail"
    @orders = @payment.orders
    @affiliate = @payment.affiliate
  end
  
  def destroy_payment
    @payment.destroy
    flash[:notice] = "Payment #{@payment.number} was deleted"
    redirect_to :action => 'payments_for_affiliate', :id => @payment.affiliate.id
  end
  
  private
    def get_affiliate
      @affiliate = Affiliate.find_by_id(params[:id])
      unless @affiliate
        flash[:notice] = "Sorry, that affiliate code is invalid"
        redirect_to :action => 'list'
        return false
      end
    end
    
    def get_payment
      @payment = AffiliatePayment.find_by_id(params[:id])
      unless @payment
        flash[:notice] = "Payment ID not found."
        redirect_to :action => 'list'
        return false
      end
    end
end
