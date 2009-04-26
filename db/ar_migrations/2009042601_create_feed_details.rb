class CreateFeedDetails < ActiveRecord::Migration

  def self.up
    create_table :feed_details, :force => true do |t|
      t.string :feedname,    :null => false
      t.string :title,       :null => false
      t.string :feed_url,    :null => false
      t.text   :description, :null => false
    end    
  end
  def self.down
    drop_table :feed_details
  end
end
