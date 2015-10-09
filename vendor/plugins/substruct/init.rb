# Copyright (c) 2010 Subimage LLC
# http://www.subimage.com
require 'substruct'
require 'substruct_deprecated'

# This plugin should be reloaded in development mode.
if RAILS_ENV == 'development'
  ActiveSupport::Dependencies.load_once_paths.reject!{|x| x =~ /^#{Regexp.escape(File.dirname(__FILE__))}/}
end