#
#
#
class Admin::FilesController < Admin::BaseController

  verify :method => :post, 
    :only => [:upload], 
    :render => {:text => "Uploading files can happen from a HTTP post only."}


  # Lists all assets / file uploads in the system.
  def index
    @title = "User uploaded files"
    get_files(params)
  end
  
  # Shows a screen where we can pick images to insert into our
  # TinyMCE editors - for ContentNode editing.
  def image_library
    @title = "Insert image"
    # Only interested in images
    get_files(params.merge({:key => 'Image'}))
    render :layout => 'admin_modal'
  end
  
  # Removes a file via AJAX
  def destroy
    @file = UserUpload.find(params[:id])
    if @file
    	@file.destroy
    end
    # Render nothing to denote success
    render :text => "" and return
  end
  
  # Uploads files from main files screen
  def upload
    files_saved = 0
    # Build product images from upload
		params[:file].each do |i|
      if i[:file_data] && !i[:file_data].blank?
        new_file = UserUpload.init(i[:file_data])
        if new_file.save
          files_saved += 1
        end
      end
    end
    
    flash[:notice] = "#{files_saved} file(s) uploaded."
    
    if params[:modal]
      redirect_to :action => 'image_library' and return
    else
      redirect_to :action => 'index' and return
    end
  end
  
  
  private
    # Gets file list for index and tinymce_library
    def get_files(params)
      if params[:sort] == 'name' then
        sort = "filename ASC"
      else
        sort = "created_on DESC"
      end

      # Set currently viewing by key
      if params[:key] then
        @viewing_by = params[:key]
        @title << " - #{@viewing_by.pluralize}"    
        @files = UserUpload.paginate(
          :order => sort,
          :page => params[:page],
          :conditions => ["type = ? and thumbnail is NULL", @viewing_by],
          :per_page => 30
        )
      else
        @files = UserUpload.paginate(
          :order => sort,
          :page => params[:page],
          :conditions => "thumbnail is NULL",
          :per_page => 30
        )
      end
    end
end