class Admin::ContentNodesController < Admin::BaseController
  include Pagination
  before_filter :set_sections

  verify :method => :post, 
    :only => [:create, :update, :destroy], 
    :redirect_to => {:action => :index}

  
  def index
    list
    render :action => 'list'
  end

  # Lists content nodes by type
  #
  def list
    @title = "Content List"
    # Get all content node types
    @list_options = ContentNode::TYPES

    # Set currently viewing by key
    if params[:key] then
      @viewing_by = params[:key]
    else
      @viewing_by = ContentNode::TYPES[0]
    end
    
    if params[:sort] == 'name' then
      sort = "name ASC"
    else
      sort = "created_on DESC"
    end

    @title << " - #{@viewing_by}"
    @content_nodes = ContentNode.paginate(
      :order => sort,
      :page => params[:page],
      :conditions => ["type = ?", @viewing_by],
      :per_page => 10
    )
    session[:last_content_list_view] = @viewing_by
  end
  
  # Shows all sections in system and lets user list content by tag.
  def list_sections
    
  end
  
  # Lists content by section
  def list_by_sections

    @list_options = Section.find_alpha

    if params[:key] then
      @viewing_by = params[:key]
    elsif session[:last_content_list_view] then
      @viewing_by = session[:last_content_list_view]
    else
      @viewing_by = @list_options[0].id
    end

    @section = Section.find(:first, :conditions => ["id=?", @viewing_by])
    if @section == nil then
			redirect_to :action => 'list'
			return
    end

    @title = "Content List For Section - '#{@section.name}'"

    conditions = nil

    session[:last_content_list_view] = @viewing_by

    # Paginate that will work with will_paginate...yee!
    per_page = 30
    list = @section.content_nodes
    pager = Paginator.new(list, list.size, per_page, params[:page])
    @content_nodes = returning WillPaginate::Collection.new(params[:page] || 1, per_page, list.size) do |p|
      p.replace list[pager.current.offset, pager.items_per_page]
    end
    
    render :action => 'list'
  end

  # Creates a content node
  def new
    @content_node = ContentNode.new
    if params[:type] && ContentNode::TYPES.include?(params[:type])
      @content_node.type = params[:type]
    else
      @content_node.type = 'Blog'
    end
    @title = "Creating New #{@content_node.type}"
  end
  
  def edit
    @content_node = ContentNode.find(params[:id])
    @title = "Editing #{@content_node.type}"
  end

  def create
    @title = "Creating a content node"
    @content_node = ContentNode.new(params[:content_node])
    @content_node.user = @logged_in_user
    
    if params[:content_node]
      @content_node.type = params[:content_node][:type]
    end

    if @content_node.save
      flash[:notice] = 'ContentNode was successfully created.'
      redirect_to :action => 'list', :key => @content_node.type
    else
      render :action => 'new'
    end
  end

  def update
    @content_node = ContentNode.find(params[:id])
    if @content_node.update_attributes(params[:content_node])
      flash.now[:notice] = 'Content was successfully updated.'
    else
      flash.now[:notice] = 'Content was NOT updated. Please check the form below.'
    end
    @title = "Editing #{@content_node.type}"
    render :action => 'edit'
  end

  def destroy
    ContentNode.find(params[:id]).destroy
    redirect_to :action => 'list'
  end
  
  private
    # Sets the sections instance variable
    #
    def set_sections
      @sections = Section.find_ordered_parents
    end
end
