# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 2009081502) do

  create_table "feed_details", :force => true do |t|
    t.string "feedname",    :null => false
    t.string "title",       :null => false
    t.string "feed_url",    :null => false
    t.text   "description", :null => false
  end

  add_index "feed_details", ["feedname"], :name => "index_feed_details_on_feedname", :unique => true

  create_table "reviews", :force => true do |t|
    t.string   "feedname",                      :null => false
    t.string   "shortname",                     :null => false
    t.datetime "date",                          :null => false
    t.string   "link",          :default => "", :null => false
    t.string   "title"
    t.binary   "description"
    t.text     "image_url",                     :null => false
    t.integer  "critic_score"
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
    t.integer  "image_height"
    t.integer  "image_width"
    t.integer  "times_checked", :default => 0
    t.datetime "last_checked"
    t.date     "score_changed"
    t.date     "release_date"
  end

  add_index "reviews", ["link"], :name => "index_reviews_on_link"
  add_index "reviews", ["link"], :name => "link"

end
