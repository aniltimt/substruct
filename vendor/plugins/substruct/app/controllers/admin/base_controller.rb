class Admin::BaseController < ApplicationController
  layout 'admin'
  before_filter :ssl_required
  
	# Check permissions for everything on the admin side.
  before_filter :login_required, :except => [:login]
	before_filter :check_authorization, :except => [:login, :index]

  before_filter :set_substruct_defaults, :except => [:login]
  private
    def set_substruct_defaults
      @logged_in_user = User.find(session[:user])
    end
end
