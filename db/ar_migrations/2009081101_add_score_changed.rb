class AddScoreChanged < ActiveRecord::Migration
  def self.up
    add_column :reviews, :score_changed,  :date
  end
  def self.down
    remove_column :reviews, :score_changed
  end
end
