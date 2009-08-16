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
    return true unless self.release_date

    return false
  end

  def self.valid_score?(score)
    score.to_i > 0 and score.to_i <= 100
  end

  def load_review
    puts "reading #{self.link}"
    page = Hpricot(open(self.link))
    begin
      self.image_url = page.search("//div[@id='bigpic']/img")[0]['src']
      self.image_height = page.search("//div[@id='bigpic']/img")[0]['height']
      self.image_width = page.search("//div[@id='bigpic']/img")[0]['width']
      score_xpath = "//table[@id='scoretable']//img"
      critic_score = page.search("//div[@id='metascore']").text.to_i
      if Review.valid_score?(critic_score)
        self.score_changed = Time.now if self.critic_score != critic_score
        self.critic_score = critic_score
      end
      self.title = page.search("//div[@id='center']/h1").text
      self.description = page.search("//div[@id='productsummary']/p").text
      release_date = page.search("//div[@id='productinfo']/p[6]/text()").to_s.strip
      self.release_date = Date.strptime(release_date, "%B %d, %Y")
    rescue
      puts "Could not load and parse #{self.link}: #{$!}"
      puts $!.backtrace
      self.reload
    ensure
      self.times_checked += 1
      self.last_checked = Time.now
      self.save
    end
  end
end

def normalize_link(link)
  link.gsub(/\?part=rss/, '')
end

def load_from_index(feedname, url)
  page = Hpricot(open(url))
  page.search("//table[@class='index']/tr/td/a").each do |elem|
    link = URI(url)
    link.path = elem['href']
    link = link.to_s
    db_item = Review.find(:first,
                          :conditions => [ "link = ?", link ])
    unless db_item
      shortname = link.gsub(/.*\/([^\/]+)$/, '\1')
      puts "Found #{feedname}/#{shortname}"
      Review.create(:link      => link,
                    :feedname  => feedname,
                    :shortname => shortname,
                    :date      => Time.now.strftime("%Y-%m-%d %H:%M:%S")
                    )
    end
  end
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
    link = normalize_link(item.link)
    db_item = Review.find(:first,
                          :conditions => [ "link = ?", link ])
    unless db_item
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
              :order => 'score_changed desc, release_date desc',
              :limit => 25,
              :conditions => [ 'critic_score IS NOT NULL AND feedname = ?', feedname]
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
    content_str += ">\n";
    content_str += "<p>"
    content_str += "<b>Critic Score:</b> #{row.critic_score}%<br>\n"
    if row.release_date
      content_str += "<b>Release Date:</b> #{row.release_date}<br>\n"
    end
    content_str += "</p>"
    description = Iconv.iconv('UTF-8//IGNORE//TRANSLIT', 'UTF-8', row.description)
    content_str += "<div>#{description}</div>"
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
  puts "scrape_metacritic <rss|index>"
  exit
end

usage unless ARGV.size == 1
APP_BASE = File.dirname(File.expand_path(__FILE__))
config = YAML.load_file(APP_BASE + "/config.yaml")
ActiveRecord::Base.establish_connection(config[:database])

if ARGV[0] == "rss"
  config[:feeds].each_pair do |feedname, feed_info|
    next unless feed_info[:source]
    puts "Looking for new reviews in #{feedname} RSS feed"
    load_from_rss(feedname, feed_info[:source])
  end
elsif ARGV[0] == "index"
  config[:feeds].each_pair do |feedname, feed_info|
    next unless feed_info[:index]
    puts "Looking for new reviews in #{feedname} index"
    load_from_index(feedname, feed_info[:index])
  end
else
  usage
end

config[:feeds].each_pair do |feedname, feed_info|
  puts "Updating reviews"
  Review.find(:all, :conditions => { :feedname => feedname },
              :order => 'shortname'
              ).each do |row|
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
