class AddTimesChecked < ActiveRecord::Migration
  def self.up
    add_column :reviews, :times_checked, :integer, :default => 0
    add_column :reviews, :last_checked,  :datetime
  end
  def self.down
    remove_column :reviews, :times_checked
    remove_column :reviews, :last_checked
  end
end
