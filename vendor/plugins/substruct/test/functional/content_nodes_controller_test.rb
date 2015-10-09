require File.dirname(__FILE__) + '/../test_helper'

class ContentNodesControllerTest < ActionController::TestCase
  fixtures :content_nodes, :sections


  # Test the show action.
  def test_show_by_id
    # TODO: Template is missing for this action.
    a_content_node = content_nodes(:home)
    
    assert_raise(ActionView::MissingTemplate) do
      get :show, :id => a_content_node.id
    end
  end


  # Test the show by name action.
  def test_show_by_name_page
    a_content_node = content_nodes(:home)
    
    get :show_by_name, :name => a_content_node.name
    assert_response :success
    assert_equal assigns(:title), a_content_node.title
    assert_template 'show_by_name'
    assert_not_nil assigns(:content_node)
    
    # Assert the content node is being shown.
    assert_select "h1", :count => 1, :text => /Welcome to Substruct/
  end

  def test_show_by_name_blog_post
    a_content_node = content_nodes(:silent_birth)
    
    get :show_by_name, :name => a_content_node.name
    assert_response :success
    assert_equal assigns(:title), a_content_node.title
    assert_template 'content_nodes/blog_post'
    assert_not_nil assigns(:content_node)
    
    # Assert the content node is being shown.
    assert_select "p", :count => 1, :text => /According to the creator of/
  end
  
  def test_show_by_content_invalid_name
    get :show_by_name, :name => "bleargh"
    assert_response :missing
  end
  

  # Test the show snippet action.
  def test_snippet
    # Now using a snippet.
    a_content_node = content_nodes(:order_receipt)
    
    get :show_snippet, :name => a_content_node.name
    assert_response :success

    assert_not_nil assigns(:content_node)    
    # Assert the content node is being shown.
    assert_select "p", :count => 1, :text => /You will be billed via credit card./
  end


  # Test the index action, showing the blog.
  def test_index
    get :index
    assert_response :success
    assert_equal assigns(:title), "Blog"
    assert_template 'index.rhtml'
    assert_not_nil assigns(:content_nodes)
    
    # Assert the blog posts are being shown.
    assert_select "a", :count => 1, :text => content_nodes(:tinkerbel_pregnant).title
    assert_select "a", :count => 1, :text => content_nodes(:pigasus_awards).title
    assert_select "a", :count => 1, :text => content_nodes(:silent_birth).title
  end
  
  def test_index_rss
    get :index, :format => 'rss'
    assert_response_rss
    assert_template 'index.rxml'
    assert assigns(:content_nodes).size > 0
  end
  
  # Test the list by section action.
  def test_list_by_section
    a_section = sections(:pseudoscientific_claims)
    
    get :list_by_section, :section_name => a_section.name
    assert_response :success
    assert_equal assigns(:title), "Blog entries for #{a_section.name}"
    assert_template 'index.rhtml'
    assert_not_nil assigns(:content_nodes)
    
    # Assert the blog posts are being shown.
    assert assigns(:sections).size > 0
    assert_select "a", :count => 1, :text => content_nodes(:pigasus_awards).title
    assert_select "a", :count => 1, :text => content_nodes(:silent_birth).title


    # Now using an invalid name.
    get :list_by_section, :section_name => "bleargh"
    assert_response :missing
  end

end
