class ContentNodesController < ApplicationController
  before_filter :set_sections
  
  layout 'main'

  def show
    @content_node = ContentNode.find(params[:id])
  end

  # Shows an entire page of content by name
  def show_by_name
    @content_node = ContentNode.find(:first, :conditions => ["name = ?", params[:name]])
    if !@content_node then
      render :file => "#{RAILS_ROOT}/public/404.html", :layout => false, :status => 404
      return
    end
    # Set a title
    if @content_node.title.blank? then
      @title = @content_node.name.capitalize
    else
      @title = @content_node.title
    end
    # Render special template for blog posts
    if @content_node.type == 'Blog' then
      render(:template => 'content_nodes/blog_post')
    else # Render basic template for regular pages
      render(:layout => 'main')
    end
  end

  # Shows a snippet of content
  def show_snippet
    @content_node = Snippet.find(:first, :conditions => ["name = ?", params[:name]])
    if @content_node
      render :text => @content_node.content, :layout => false and return
    else
      render :text => '', :layout => false and return
    end
  end

  # Shows all blog content nodes.
  # Can render HTML or RSS format.
  def index
    @title = "Blog"
    respond_to do |format|
      format.html do
        @content_nodes = Blog.paginate(
          :conditions => 'display_on <= CURRENT_DATE',
          :page => params[:page],
          :per_page => 5,
          :order => 'display_on DESC, created_on DESC'
        )
        render :action => 'index.rhtml' and return
      end
      format.rss do
        @content_nodes = Blog.find(
          :all,
          :conditions => 'display_on <= CURRENT_DATE',
          :order => 'display_on DESC, created_on DESC'
        )
        render :action => 'index.rxml', :layout => false and return
      end
    end
  end
  
  # Lists blog entries by section
  #
  def list_by_section
    # Find section, if no section 404...
    @section = Section.find_by_name(params[:section_name])
    if !@section then
      render :file => "#{RAILS_ROOT}/public/404.html", :layout => false, :status => 404
      return
    end
    @title = "Blog entries for #{@section.name}"
    @content_nodes = @section.blogs.paginate(
      :conditions => 'display_on <= CURRENT_DATE',
      :page => params[:page],
      :per_page => 5
    )
    render :action => 'index.rhtml' and return
  end

  private
    # Sets the sections instance variable
    #
    def set_sections
      @sections = Section.find_ordered_parents
    end

end