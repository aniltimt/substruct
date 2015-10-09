class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details
  
  include SubstructApplicationController  
  before_filter :set_substruct_view_defaults
  before_filter :get_nav_tags
  before_filter :find_customer
end