# Load the normal Rails helper. This ensures the environment is loaded.
require File.expand_path(File.dirname(__FILE__) + '/../../../../test/test_helper')

# Load the schema - if migrations have been performed, this will be up to date.
#load(File.dirname(__FILE__) + "/../db/schema.rb")
#Rake::Task['db:test:prepare']

# Set up the fixtures location manually, we don't want to move them to a
# temporary path using Engines::Testing.set_fixture_path.
# This works with unit and functional tests.
ActiveSupport::TestCase.fixture_path = File.dirname(__FILE__) + "/fixtures/"
$LOAD_PATH.unshift(ActiveSupport::TestCase.fixture_path)
# This is needed for integration tests.
ActionController::IntegrationTest.fixture_path = File.dirname(__FILE__) + "/fixtures/"
$LOAD_PATH.unshift(ActionController::IntegrationTest.fixture_path)

# This is necessary for using fixture_file_path with Rails 2.3
# See https://rails.lighthouseapp.com/projects/8994/tickets/1985-fixture_file_upload-no-longer-available-in-tests-by-default
class ActiveSupport::TestCase
  include ActionController::TestProcess
end

# The only drawback to using transactional fixtures is when you actually 
# need to test transactions.  Since your test is bracketed by a transaction,
# any transactions started in your code will be automatically rolled back.
ActiveSupport::TestCase.use_transactional_fixtures = true

# Instantiated fixtures are slow, but give you @david where otherwise you
# would need people(:david).  If you don't want to migrate your existing
# test cases which use the @david style and don't mind the speed hit (each
# instantiated fixtures translates to a database query per test method),
# then set this back to true.
ActiveSupport::TestCase.use_instantiated_fixtures  = false

# We don't want our tests with images messing with "public/system" used in
# development and production, and creating images with ids that only exists in
# the test database or overwriting things.
Image.attachment_options[:path_prefix] = "public/test/"


# Require mocha.
require 'mocha'
include Substruct::Assertions

### Helper methods for test cases ###

def login_as(user)
  @request.session[:user] = users(user).id
end

def login_as_customer(customer)
  @request.session[:customer] = order_users(customer).id
end

# Unfortunately url_for doesn't work as is inside tests, so, a fix.
def url_for(options)
  url = ActionController::UrlRewriter.new(@request, nil)
  url.rewrite(options)
end