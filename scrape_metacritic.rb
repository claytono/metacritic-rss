#!/usr/bin/env ruby

require 'rubygems'
require 'rss/1.0'
require 'rss/2.0'
require 'atom/feed'
require 'open-uri'
require 'hpricot'
require 'activerecord'
require 'pp'
require 'yaml'

class FeedDetail < ActiveRecord::Base
end

class Review < ActiveRecord::Base
  def needs_update?
    return true unless self.last_checked
    time_between = self.times_checked * 60 * 60 * 12
    next_check = self.last_checked + time_between
    if Time.now < next_check
      puts "skipping #{shortname} due to time"
      return false
    end

    return true unless Review.valid_score?(self.critic_score)
    return true unless self.image_height
    return true unless self.image_width

    return false
  end

  def self.valid_score?(score)
    score.to_i > 0 and score.to_i <= 100
  end

  def load_review
    page = Hpricot(open(self.link))
    self.image_url = page.search("//table[@id='scoretable']//img[@src]")[0]['src']
    self.image_height = page.search("//table[@id='scoretable']//img[@src]")[0]['height']
    self.image_width = page.search("//table[@id='scoretable']//img[@src]")[0]['width']
    score_xpath = "//table[@id='scoretable']//img"
    critic_score = page.search(score_xpath)[2][:alt].gsub(/Metascore:\s*/i, '')
    self.critic_score = critic_score if Review.valid_score?(critic_score)
    self.title = page.search("//table[@class='gameshead']//td")[0].to_plain_text
    self.description = page.search("//div[@id='midsection']/p").text
    self.save
  end
end

def normalize_link(link)
  link.gsub(/\?part=rss/, '')
end

def load_from_rss(feedname, url)
  content = ""
  open(url) { |s| content = s.read }
  rss = RSS::Parser.parse(content, false)
  detail = FeedDetail.find_or_initialize_by_feedname(feedname)
  detail.title = rss.channel.title
  detail.feed_url  = rss.channel.link
  detail.description = rss.channel.description
  detail.save

  rss.items.each do |item|
    db_item = Review.find(:first,
                          :conditions => [ "link = ?", normalize_link(item.link) ])
    unless db_item
      link = normalize_link(item.link)
      shortname = link.gsub(/.*\/([^\/]+)$/, '\1')
      Review.create(:link      => link,
                    :feedname  => feedname,
                    :shortname => shortname,
                    :date      => item.date.strftime("%Y-%m-%d %H:%M:%S")
                    )
    end
  end
end

def write_feed(destination, feedname, self_link)
  feed = Atom::Feed.new
  detail = FeedDetail.find_by_feedname(feedname)
  feed.title = detail.title
  feed.id = detail.feed_url
  feed.subtitle = detail.description
  feed.links << Atom::Link.new(:href => self_link, :rel => 'self')

  Review.find(:all,
              :order => 'updated_at',
              :limit => 25,
              :conditions => [ 'critic_score IS NOT NULL and feedname = ?', feedname]
              ).each do |row|
    puts "Writing #{row.title} to #{feedname}.xml"
    item = Atom::Entry.new
    item.title = "#{row.critic_score}% #{row.title}"
    item.id = row.link
    item.links << Atom::Link.new(:href => row.link)
    item.authors << Atom::Author.new(:name => 'Metacritic')
    item.published = row.created_at
    item.updated = row.updated_at
    feed.updated = row.updated_at if not feed.updated or feed.updated < row.updated_at

    content_str = "<img src=\"#{row.image_url}\""
    content_str += " height=\"#{row.image_height}\"" if row.image_height
    content_str += " width=\"#{row.image_width}\""   if row.image_width
    description = Iconv.iconv('UTF-8//IGNORE//TRANSLIT', 'UTF-8', row.description)
    content_str += "><div>#{description}</div>"
    item.content = content_str
    item.content.type = "html"
    feed << item
  end
  feed.updated = Time.now unless feed.updated

  filename = "#{destination}/#{feedname}.xml"
  File.open(filename, "w") do |f|
    f.write(feed)
  end
end

def usage
  puts "scrape_metacritic <configfile.yaml>"
  exit
end

APP_BASE = File.dirname(File.expand_path(__FILE__))
usage unless ARGV.size == 0
config = YAML.load_file(APP_BASE + "/config.yaml")
ActiveRecord::Base.establish_connection(config[:database])

config[:feeds].each_pair do |feedname, feed_info|
  load_from_rss(feedname, feed_info[:source])

  # Update reviews
  Review.find(:all, :conditions => { :feedname => feedname }).each do |row|
    if row.needs_update?
      puts "#{feedname}/#{row.shortname}: Loading review"
      row.load_review
      if row.critic_score
        puts "#{feedname}/#{row.shortname}: score = #{row.critic_score}"
      end
    end
  end
  write_feed(config[:destination], feedname, feed_info[:self])
end
