class AddLinkIndex < ActiveRecord::Migration
  def self.up    
    change_column(:reviews, :link, :string, 
                  :limit => 255, 
                  :null => false
                  )
    add_index(:reviews, :link)
  end
  def self.down
    remove_index(:reviews, :link)
    change_column(:reviews, :link, :text,
                  :null => false)
  end
end
