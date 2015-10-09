require File.dirname(__FILE__) + '/../../test_helper'

class Admin::ContentNodesControllerTest < ActionController::TestCase
  fixtures :rights, :roles, :users
  fixtures :content_nodes, :sections

  def setup
    login_as :admin
    @cn = content_nodes(:silent_birth)
  end

  def test_index_success
    get :index
    assert_response :success
    assert_template 'list'
  end

  def test_list_success
    get :list
    assert_response :success
    assert_template 'list'
    assert_equal assigns(:title), "Content List - Blog"
    assert_not_nil assigns(:content_nodes)
  end

  def test_list_with_keys_success
    get :list, :key => "Blog"
    assert_response :success
    assert_template 'list'
    assert_equal assigns(:title), "Content List - #{assigns(:viewing_by)}"
    assert_not_nil assigns(:content_nodes)

    get :list, :key => "Page"
    assert_response :success
    assert_template 'list'
    assert_equal assigns(:title), "Content List - #{assigns(:viewing_by)}"
    assert_not_nil assigns(:content_nodes)

    get :list, :key => "Snippet"
    assert_response :success
    assert_template 'list'
    assert_equal assigns(:title), "Content List - #{assigns(:viewing_by)}"
    assert_not_nil assigns(:content_nodes)

    # Here it should sort by name and remember the last key.
    get :list, :sort => "name"
    assert_response :success
    assert_template 'list'
    assert_equal assigns(:title), "Content List - #{assigns(:viewing_by)}"
    assert_not_nil assigns(:content_nodes)
  end
  
  def test_list_sections_success
    get :list_sections
    assert_response :success
    assert_template 'list_sections'
  end

  # Call it first without a key, it will use the first by name.  
  def test_list_by_sections_no_key
    get :list_by_sections
    assert_response :success
    assert_template 'list'
    assert_equal assigns(:title), "Content List For Section - '#{Section.find_alpha[0].name}'"
    assert_not_nil assigns(:content_nodes)
  end

  def test_list_by_sections_with_key_remembers
    # Now call it again with a key.
    a_section = sections(:junk_food_news)
    
    get :list_by_sections, :key => a_section.id
    assert_response :success
    assert_template 'list'
    assert_equal assigns(:title), "Content List For Section - '#{a_section.name}'"
    assert_not_nil assigns(:content_nodes)


    # Now call it again without a key, it should remember.
    get :list_by_sections
    assert_response :success
    assert_template 'list'
    assert_equal assigns(:title), "Content List For Section - '#{a_section.name}'"
    assert_not_nil assigns(:content_nodes)
  end
  
  def test_list_by_sections_invalid
    a_section = sections(:junk_food_news)
    
    # Now delete this section making it invalid.
    a_section.destroy
    get :list_by_sections, :key => a_section.id
    # If invalid we should be redirected to list. 
    assert_response :redirect
    assert_redirected_to :action => :list
  end
  
  def test_get_new_no_type_specified
    get :new
    assert_response :success
    assert_template 'new'
    assert_equal 'Blog', assigns(:content_node).type
  end
  
  def test_get_new_valid_content_types
    ContentNode::TYPES.each do |type|
      get :new, :type => type
      assert_response :success
      assert_equal type, assigns(:content_node).type
      # Ensures hidden input set with proper value
      assert_select "input#content_node_type[value=#{type}]"
    end
  end
  
  def test_get_new_invalid_content_type
    ['invalid', 'content', 'types'].each do |type|
      get :new, :type => type
      assert_response :success
      assert_equal 'Blog', assigns(:content_node).type
    end
  end
  
  def test_create_success_blog
    assert_create_success('Blog')
  end
  
  def test_create_success_page
    assert_create_success('Page')
  end
  
  def test_create_success_snippet
    assert_create_success('Snippet')
  end
  
  def assert_create_success(node_type)    
    post(
      :create,
      :content_node => {
        :title => "Prophecies for 2008",
        :name => 'prophecies',
        :display_on => 1.minute.ago.to_s(:db),
        :content => "According to the Church of Who Knows Where:
      1. The Lord say there would be some scientific breakthrough this year.
      2. There would be some major medical breakthrough this year.
      3. We must pray against destructive hurricane.
      4. To be fore warned is to be fore armed, the flood in this year will be more than last year.
      ",
        :type => node_type,
        :sections => ["", sections(:prophecies).id.to_s]
      }
    )
    
    assert_response :redirect
    assert_redirected_to :action => :list, :key => node_type
    
    # Verify that the blog post really is there.
    some_content = ContentNode.find_by_name('prophecies')
    assert_kind_of ContentNode, some_content
    
    assert_equal(
      users(:admin), some_content.user,
      "Logged in user should have been set as content creator"
    )
  end


  def test_create_failure
    post :create,
    :content_node => {
      :title => "",
      :name => "",
      :display_on => 1.minute.ago.to_s(:db),
      :content => "",
      :type => "Blog",
      :sections => ["", sections(:prophecies).id.to_s]
    }
    
    # If not saved we will NOT receive a HTTP error status. As we will not be
    # redirected to list action too. The same page will be rendered again with
    # error explanations.
    assert_response :success
    assert_template 'new'

    # Here we assert that the proper fields was marked.
    assert_select "div.fieldWithErrors input#content_node_title"
    assert_select "div.fieldWithErrors input#content_node_name"
    assert_select "div.fieldWithErrors textarea#content_node_content"
  end


  def test_get_edit_success
    # Call the edit form.
    get :edit, :id => @cn.id
    assert_response :success
    assert_template 'edit'
  end
  
  def test_update_success
    # Post to it a content node.
    post :update,
    :id => @cn.id,
    :content_node => {
      :title => "Silent",
      :name => "silent_birth",
      :display_on => 1.minute.ago.to_s(:db),
      :content => "According to the creator of scientology: Stemming from his belief that birth is a trauma that may induce engrams, he stated that the delivery room should be as silent as possible and that words should be avoided because any words used during birth might be reassociated by adults with their earlier traumatic birth experience. And bla bla bla bla bla ...",
      :sections => [""]
    },
    :file => [ {
      :file_data => "",
      :file_data_temp => ""
    }, {
      :file_data => "",
      :file_data_temp => ""
    } ]
    
    # If saved we should be redirected to list. 
    assert_response :success
    
    # Verify that the change was made.
    @cn.reload
    assert_equal @cn.title, "Silent"
  end

  # Change attributes from a content node making it invalid, it should NOT be saved.
  def test_edit_failure
    post :update,
    :id => @cn.id,
    :content_node => {
      :title => "",
      :name => "",
      :display_on => 1.minute.ago.to_s(:db),
      :content => "According to the creator of scientology: Stemming from his belief that birth is a trauma that may induce engrams, he stated that the delivery room should be as silent as possible and that words should be avoided because any words used during birth might be reassociated by adults with their earlier traumatic birth experience. And bla bla bla bla bla ...",
      :type => "Blog",
      :sections => [""]
    },
    :file => [ {
      :file_data => "",
      :file_data_temp => ""
    }, {
      :file_data => "",
      :file_data_temp => ""
    } ]
    
    # If not saved we will NOT receive a HTTP error status. As we will not be
    # redirected to list action too. The same page will be rendered again with
    # error explanations.
    assert_response :success
    assert_template 'edit'

    # Here we assert that the proper fields was marked.
    assert_select "div.fieldWithErrors input#content_node_title"
    assert_select "div.fieldWithErrors input#content_node_name"
  end

  # Test if we can remove content nodes.
  def test_destroy_success
    assert ContentNode.exists?(@cn)
    assert_difference "ContentNode.count", -1 do
      post :destroy, :id => @cn.id
    end
    assert !ContentNode.exists?(@cn)
  end
  
  def test_destroy_get_failure
    assert_no_difference "ContentNode.count" do
      get :destroy, :id => @cn.id
    end
    assert_redirected_to :action => 'index'
  end

end