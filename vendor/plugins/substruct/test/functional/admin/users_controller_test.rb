require File.dirname(__FILE__) + '/../../test_helper'

class Admin::UsersControllerTest < ActionController::TestCase
  fixtures :rights, :roles, :users

  # Test the index action.
  def test_index
    login_as :admin

    get :index
    assert_response :success
    assert_template 'list'
  end


  # Test the list action.
  def test_list
    login_as :admin

    get :list
    assert_response :success
    assert_template 'list'
    assert_equal assigns(:title), "Admin User List"
    assert_not_nil assigns(:users)
  end
  
  
  # Test the create action. Here we test if a new valid user will be saved.
  def test_new_get
    login_as :admin

    # Call the new form.
    get :new
    assert_response :success
    assert_template 'new'
  end
    
  def test_new_post_success
    login_as :admin
    # Post to it a user.
    post :new,
      :user => {
        :login => "root",
        :password => "password",
        :password_confirmation => "password",
        :role_ids => ["", roles(:administrator_role).id.to_s]
      }
    
    # If saved we should be redirected to list. 
    assert_response :redirect
    assert_redirected_to :action => :list
    
    # Verify that the user really is there.
    user = User.find_by_login('root')
    assert_not_nil user
  end


  # Test the create action. Here we test if a new invalid user will NOT be
  # saved.
  def test_new_post_fail
    login_as :admin
  
    # Post to it a user.
    post :new,
      :user => {
        :login => "",
        :password => "",
        :password_confirmation => "",
        :role_ids => ["", roles(:administrator_role).id.to_s]
      }
    
    # If not saved we will NOT receive a HTTP error status. As we will not be
    # redirected to list action too. The same page will be rendered again with
    # error explanations.
    assert_response :success
    assert_template 'new'

    # Here we assert that the proper fields was marked.
    assert_select "div.fieldWithErrors input#user_login"
    assert_select "div.fieldWithErrors input#user_password"
  end


  # Change attributes from user.
  def test_edit
    login_as :admin    
    user = users(:c_norris)

    # Call the edit form.
    get :edit, :id => user.id
    assert_response :success
    assert_template 'edit'
  end

  def test_edit_post_success
    login_as :admin    
    user = users(:c_norris)
    
    # Post to it a user.
    post :edit,
      :id => user.id,
      :user => {
        :login => "chuck",
        :password => "",
        :password_confirmation => "",
        :role_ids => ["", roles(:administrator_role).id.to_s]
      }
    
    # If saved we should be redirected to list. 
    assert_response :redirect
    assert_redirected_to :action => :list
    
    # Verify that the change was made.
    user.reload
    assert_equal user.login, "chuck"
  end


  # Change attributes from user making it invalid, it should NOT be saved.
  def test_edit_post_fail
    login_as :admin    
    user = users(:c_norris)

    post :edit,
      :id => user.id,
      :user => {
        :login => "",
        :password => "",
        :password_confirmation => "",
        :role_ids => ["", roles(:administrator_role).id.to_s]
      }
    
    # If not saved we will NOT receive a HTTP error status. As we will not be
    # redirected to list action too. The same page will be rendered again with
    # error explanations.
    assert_response :success
    assert_template 'edit'

    # Here we assert that the proper fields was marked.
    assert_select "div.fieldWithErrors input#user_login"
  end


  # Test if we can remove users.
  def test_destroy_success
    login_as :admin

    user = users(:c_norris)

    # Post to it a user.
    post :destroy, :id => user.id

    # If removed we should be redirected to list.
    assert_response :redirect
    assert_redirected_to :action => :list

    # See if the user is NOT there.
    assert_raise(ActiveRecord::RecordNotFound) {
      User.find(user.id)
    }
  end


  # Test if we will really NOT be able to delete the account we loged on.
  def test_destroy_cant_remove_self
    login_as :admin

    user = users(:admin)

    # Setting reference url (to have a place to be redirected).
    ref_url = url_for :controller => 'admin/users', :action => 'index'
    @request.env["HTTP_REFERER"] = ref_url

    ### Try to delete yourself.

    # Post to it a user.
    post :destroy, :id => user.id

    # If not removed we should be redirected back. 
    assert_response :redirect
    assert_redirected_to :action => :list

    # See if the user is there.
    assert_nothing_raised {
      User.find(user.id)
    }

    ### Try to delete yourself when you are the only user.
    post :destroy, :id => users(:c_norris).id

    # Post to it a user.
    post :destroy, :id => user.id
    # If not removed we should be redirected back. 
    assert_response :redirect
    assert_redirected_to :action => :list

    # See if the user is there.
    assert_nothing_raised {
      User.find(user.id)
    }
  end

end
