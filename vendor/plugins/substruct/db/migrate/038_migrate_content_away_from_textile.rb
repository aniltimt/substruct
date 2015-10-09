# We're no longer supporting textile markup.
# See this for info
# http://code.google.com/p/substruct/issues/detail?id=205&q=milestone%3Dv1.3#makechanges
require 'substruct_deprecated'
require 'redcloth'
class MigrateContentAwayFromTextile < ActiveRecord::Migration
  extend Substruct
  
  def self.up
    puts "Converting textile formatted content into HTML for use with new rich content editor"
    
    puts "Upgrading ContentNodes"
    ContentNode.find(:all).each do |cn|
      cn.update_attribute(:content, get_markdown(cn.content))
    end
    
    puts "Upgrading Product descriptions"
    Product.find(:all).each do |p|
      p.update_attribute(:description, get_markdown(p.description))
    end
  end

  def self.down
    # There's real no way to reverse this.
  end
end