class AddReleaseDate < ActiveRecord::Migration
  def self.up
    add_column(:reviews, :release_date, :date)
  end
  def self.down
    remove_column(:reviews, :release_date)
  end
end
