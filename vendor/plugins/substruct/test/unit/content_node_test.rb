require File.dirname(__FILE__) + '/../test_helper'

class ContentNodeTest < ActiveSupport::TestCase
  fixtures :content_nodes, :sections, :users


  # Test if a valid content node can be created with success.
  def test_should_create_content_node
    cn = ContentNode.new
    
    cn.name = "prophecies"
    cn.created_on = "2008-02-29 18:15:28 -03:00"
    cn.title = "Prophecies for 2008"
    cn.type = "Blog"
    cn.display_on = 1.minute.ago.to_s(:db)
    cn.content = "According to the Church of Who Knows Where:
    1. The Lord say there would be some scientific breakthrough this year.
    2. There would be some major medical breakthrough this year.
    3. We must pray against destructive hurricane.
    4. To be fore warned is to be fore armed, the flood in this year will be more than last year.
    "

    assert cn.save
  end


  # VALIDATIONS ---------------------------------------------------------------

  # Test if a content node will have its name cleaned before being validated.
  def test_should_have_a_clean_name_before_validated
    cn = ContentNode.new
    
    cn.name = "Prophecies for!'2008'?"
    cn.valid?
    assert_equal cn.name, "prophecies-for-2008"
  end


  # Test if an invalid content node really will NOT be created.
  def test_should_not_create_invalid_content_node
    cn = ContentNode.new
    assert !cn.valid?
    assert cn.errors.invalid?(:name)
    assert cn.errors.invalid?(:title)
    assert cn.errors.invalid?(:content)
    # A content node must have a name, a title and a content.
    assert_equal "can't be blank", cn.errors.on(:name)
    assert_equal "can't be blank", cn.errors.on(:title)
    assert_equal "can't be blank", cn.errors.on(:content)
  end
  
  def test_node_validates_unique_url
    dupe_node = content_nodes(:silent_birth)
    assert dupe_node.update_attribute(:url, 'unique-url')
    
    node = ContentNode.new
    node.attributes = content_nodes(:silent_birth).attributes

    assert !node.save
    assert_equal(
      "This URL has already been taken. Create a unique URL please.", 
      node.errors.on(:name)
    )
  end
  
  def test_saves_with_valid_types
    n = ContentNode.new(
      :title => 'My title',
      :content => 'Good content'
    )
    ContentNode::TYPES.each do |type|
      n.type = type
      assert n.save
      assert_equal type, n.type
    end
  end
  
  def test_doesnt_save_with_invalid_types
    n = ContentNode.new(
      :title => 'My title',
      :content => 'Good content'
    )
    invalid_types = ['some', 'invalid', 'types']
    invalid_types.each do |type|
      n.type = type
      assert n.save
      assert_equal 'Blog', n.type
    end
  end

  # INSTANCE METHODS ----------------------------------------------------------

  # Test if a content node can be found with success.
  def test_should_find_content_node
    cn_id = content_nodes(:silent_birth).id
    assert_nothing_raised {
      ContentNode.find(cn_id)
    }
  end


  # Test if a content node can be updated with success.
  def test_should_update_content_node
    cn = content_nodes(:silent_birth)
    assert cn.update_attributes(:name => 'silent')
  end


  # Test if a content node can be destroyed with success.
  def test_should_destroy_content_node
    cn = content_nodes(:silent_birth)
    cn.destroy
    assert_raise(ActiveRecord::RecordNotFound) {
      ContentNode.find(cn.id)
    }
  end


  
  def test_node_saves_generates_url
    node = ContentNode.new(
      :title => "Some wonderful piece of content",
      :content => "Blah blah blah"
    )
    assert node.save
    assert_equal(
      'some-wonderful-piece-of-content',
      node.name
    )
  end
  
  def test_node_generates_display_date_when_null
    node = ContentNode.new(
      :title => "Some wonderful piece of content",
      :content => "Blah blah blah"
    )
    assert_nil node.display_on
    
    assert node.save
    assert_equal(
      Date.today,
      node.display_on
    )
  end
  
  def test_node_doesnt_overwrite_date
    node = content_nodes(:silent_birth)
    node_publish_date = node.display_on
    assert_not_equal Date.today, node_publish_date
    assert node.save
    assert_equal node_publish_date, node.display_on
  end

  # TODO: Get rid of this method if it will not be used.
  # Test if a content node is a blog post.
  def test_should_discover_if_content_node_is_a_blog_post
    assert content_nodes(:silent_birth).is_blog_post?
  end

  # Test if we can associate a section.
  def test_should_associate_sections
    cn = content_nodes(:tinkerbel_pregnant)
    assert_equal cn.sections.count, 0
    
    # Sections must be passed as an array of strings with numeric values.
    cn.sections =  ["", "#{sections(:junk_food_news).id}", "#{sections(:celebrity_pregnancies).id}"]
    cn.save
    cn.reload
    assert_equal cn.sections.count, 2
  end

  # TODO: Get rid of this method if it will not be used.
  # Test if the name will be returned when we ask for its url.
  def test_should_return_name_on_url
    cn = content_nodes(:tinkerbel_pregnant)
    assert_equal cn.url, cn.name
  end
  
  def test_created_by
    cn = content_nodes(:tinkerbel_pregnant)
    cn.stubs(:user).returns users(:admin)
    
    assert_equal cn.user.login, cn.created_by
  end
  
  def test_created_by_nil
    cn = content_nodes(:tinkerbel_pregnant)
    cn.stubs(:user).returns nil
    
    assert_equal '', cn.created_by
  end
  
  def test_short_content
    cn = content_nodes(:silent_birth)
    
    assert cn.content.include?(ContentNode::PAGEBREAK)
    assert !cn.short_content.include?(ContentNode::PAGEBREAK)
    
    extended_content = 'This line is extended content and should appear after the "jump" on the blog section'
    assert(
      !cn.short_content.include?(extended_content),
      "Extended content should not be included in short content"
    )
  end
  
  # Ensures output of short_content is cleaned in some way.
  def test_short_content_doesnt_end_with_open_tag
    cn = content_nodes(:silent_birth)
    assert cn.content.include?(ContentNode::PAGEBREAK)
    assert_not_equal(
      cn.short_content.rindex("<p>"),
      cn.short_content.size-3,
      "Short content shouldn't end with an open paragraph tag."
    )
  end

end
