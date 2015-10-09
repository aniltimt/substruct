namespace :substruct do
  namespace :upgrade do
    
    desc "Upgrades Substruct from Rails v2.1.2 to v2.3.8"
    task :v1_3 do
      # Replace gem version in environment
      puts "Changing rails gem version"
      
      gem_str_to_replace = "RAILS_GEM_VERSION = '2.1.2' unless defined? RAILS_GEM_VERSION"
      gem_str_replacement = "RAILS_GEM_VERSION = '2.3.8' unless defined? RAILS_GEM_VERSION"
      env_file = File.join(RAILS_ROOT, 'config/environment.rb')
      # Open, read, replace, write...
      env_text = File.read(env_file)
      File.open(env_file, "w") do |f|
        f.puts env_text.gsub(gem_str_to_replace, gem_str_replacement)
      end

      
      # Remove old style routing include in config/routes.rb
      puts "Updating config/routes.rb"
      
      routes_file = File.join(RAILS_ROOT, 'config/routes.rb')
      routes_text = File.read(routes_file)
      File.open(routes_file, "w") do |f|
        f.puts routes_text.gsub("map.from_plugin :substruct", "")
      end
      
      
      puts "Renaming application.rb to application_controller.rb"
      
      old_app_file = File.join(RAILS_ROOT, 'app/controllers/application.rb')
      if File.exist?(old_app_file)
        File.rename(
          old_app_file, 
          File.join(RAILS_ROOT, 'app/controllers/application_controller.rb')
        )
      end
    end
  end
end