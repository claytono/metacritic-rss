require 'active_record'
require 'yaml'

APP_BASE = File.dirname(File.expand_path(__FILE__))

namespace :db do
  task :ar_init do
    # set a logger for STDOUT
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    config = YAML.load_file(APP_BASE + "/config.yaml")
    ActiveRecord::Base.establish_connection(config[:database])    
  end
 
  desc "Migrate the database through scripts in db/migrate. " +
    "Target specific version with VERSION=x. Turn off output with VERBOSE=false."
  task :migrate => :ar_init  do
    ActiveRecord::Migration.verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
    ActiveRecord::Migrator.migrate(APP_BASE + "/db/ar_migrations/", 
                                   ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
    Rake::Task["db:schema:dump"].invoke if ActiveRecord::Base.schema_format == :ruby
  end
  
  namespace :schema do
    desc "Create a db/ar_schema.rb file that can be portably used against " +
      "any DB supported by AR"
    task :dump => :ar_init do
      require 'active_record/schema_dumper'
      File.open(ENV['SCHEMA'] || APP_BASE + "/db/ar_schema.rb", "w") do |file|
        ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
      end
    end
    
    desc "Load a ar_schema.rb file into the database"
    task :load => :ar_init do
      file = ENV['SCHEMA'] || APP_BASE + "/db/ar_schema.rb"
      load(file)
    end
  end
end
