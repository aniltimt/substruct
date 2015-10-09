class Admin::CustomersController < Admin::BaseController         
  before_filter :get_customer,
    :only => [:show]

  def index
    list()
  end

  # Lists customers in the system.
  def list
    respond_to do |format|
      format.html do
        @title = "Customer List"
        @customers = OrderUser.paginate(
          :include => ['orders'],
          :order => "last_name ASC, first_name ASC",
          :page => params[:page],
          :per_page => 30
        )
        render :action => 'list' and return
      end
      format.csv do
        require 'fastercsv'
        send_data(
          OrderUser.get_csv_for(OrderUser.find(:all)),
          :filename => Time.now.strftime("Customer_list-%m_%d_%Y_%H-%M.csv"),
          :type => 'text/csv'
        ) and return
      end
    end
  end
  
  private
  
    def get_customer
      @customer = OrderUser.find_by_id(params[:id])
      unless @customer
        flash[:notice] = "Customer not found. Bad link?"
        redirect_to :action => 'index' and return false
      end
    end
  
end