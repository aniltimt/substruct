### Custom assertions for test cases ####
module Substruct
  module Assertions

    def assert_error_on(field, model)
    	assert !model.errors[field.to_sym].nil?, "No validation error on the #{field.to_s} field."
    end

    def assert_no_error_on(field, model)
    	assert model.errors[field.to_sym].nil?, "Validation error on #{field.to_s}."
    end

    # Assert that two arrays have the same elements independent of the order.
    def assert_same_elements(an_array, another_array)
      assert_equal an_array - another_array, another_array - an_array
    end

    # Assertion to test layout for controllers
    def assert_layout(layout)
      assert_equal "layouts/#{layout}", @response.layout
    end


    # The assert_working_associations method simply walks through all of the 
    # associations on the class and sends the model the name of the association.
    # This catch-all ensures that with a single line of code per model, 
    # I can invoke all relationships on all of our model tests.
    def assert_working_associations(m=nil)
      m ||= self.class.to_s.sub(/Test$/, '').constantize
      @m = m.new
      m.reflect_on_all_associations.each do |assoc|
        assert_nothing_raised("#{assoc.name} caused an error") do
          @m.send(assoc.name, true)
        end
      end
      true
    end

    def assert_valid_presence(obj, *arguments)
      arguments.each {|a| obj[a] = nil}
      assert !obj.valid?, "Object was valid when it shouldn't be."
      arguments.each do |a| 
        assert obj.errors.invalid?(a), "#{obj.class} valid with '#{a}' nil when it shouldn't be."
      end
    end

    def assert_valid_uniqueness(obj, obj_same, property)
      obj[property] = obj_same[property]
      assert !obj.save
      assert_error_on property, obj
    end
    
    # CONTROLLER ASSERTIONS ---------------------------------------------------
    def assert_cant_get(action, redirection_hash = {})
      get action
      assert_redirected_to redirection_hash
    end
    
    # assert_format :iphone
    def assert_format(format)
      assert_equal format.to_sym, @request.format.to_sym
    end

    def assert_response_xml
      assert_response :success
      assert_equal 'application/xml; charset=utf-8', @response.headers['Content-Type']
    end
    
    def assert_response_rss
      assert_response :success
      assert_equal 'application/rss+xml; charset=utf-8', @response.headers['Content-Type']
    end
    
    def assert_response_js
      assert_response :success
      assert_equal 'text/javascript; charset=utf-8', @response.headers['Content-Type']
    end
    
    def assert_response_pdf
      assert_response :success
      assert_equal 'application/pdf', @response.headers['Content-Type']
    end
    
    def assert_response_json
      assert_response :success
      assert_equal 'application/json; charset=utf-8', @response.headers['Content-Type']
    end
  
    def assert_response_csv
      assert_response :success
      assert_equal 'text/csv', @response.headers['Content-Type']
    end
    
  end
end