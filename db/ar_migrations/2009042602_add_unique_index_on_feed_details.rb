class AddUniqueIndexOnFeedDetails < ActiveRecord::Migration
  def self.up
    add_index(:feed_details, :feedname, :unique => true)
  end
  def self.down
    remove_index(:feed_details, :feedname)
  end
end
