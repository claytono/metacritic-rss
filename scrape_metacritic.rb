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

class RssItem < ActiveRecord::Base
  def self.load_from_rss(url)
    content = ""
    open(url) do |s| content = s.read end
    rss = RSS::Parser.parse(content, false)
    rss.items.each do |item| 
      db_item = RssItem.find(:first, 
                             :conditions => [ "link = ?", normalize_link(item.link) ])
      unless db_item
        link = normalize_link(item.link)
        shortname = link.gsub(/.*\/([^\/]+)$/, '\1')
        RssItem.create(:link      => link,
                       :shortname => shortname,
                       :date      => item.date.strftime("%Y-%m-%d %H:%M:%S")
                       )
      end
    end
  end

  def needs_update?
    return 1 unless RssItem.valid_score?(self.critic_score)
    return 1 unless self.image_height
    return 1 unless self.image_width
    return
  end
  
  def self.valid_score?(score)
    score.to_i > 0 and score.to_i <= 100
  end

  def self.normalize_link(link)
    link.gsub(/\?part=rss/, '')
  end

  def load_review
    page = Hpricot(open(self.link))
    self.image_url = page.search("//table[@id='scoretable']//img[@src]")[0]['src']
    self.image_height = page.search("//table[@id='scoretable']//img[@src]")[0]['height']
    self.image_width = page.search("//table[@id='scoretable']//img[@src]")[0]['width']
    score_xpath = "//table[@id='scoretable']//img"
    critic_score = page.search(score_xpath)[2][:alt].gsub(/Metascore:\s*/i, '')
    self.critic_score = critic_score if RssItem.valid_score?(critic_score)
    self.title = page.search("//table[@class='gameshead']//td")[0].to_plain_text
    self.description = page.search("//div[@id='midsection']/p").text
    self.save
  end
end

config = YAML.load_file(ARGV[0])
ActiveRecord::Base.establish_connection(config[:database])

RssItem.load_from_rss(config[:source_url])
# Update reviews
RssItem.find(:all, 
             :conditions => "critic_score IS NULL"
             ).each do |row|
  if row.needs_update?
    puts "#{row.shortname}: Loading review"
    row.load_review
    puts "#{row.shortname}: score = #{row.critic_score}" if row.critic_score

  end
end

feed = Atom::Feed.new
feed.title = 'Metacritic.com: Xbox 360 Reviews'
feed.id = config[:source_url]
feed.links << Atom::Link.new(:href => 'http://www.metacritic.com/rss/games/xbox360')
feed.subtitle = 'Metacritic Games compiles reviews from dozens of publications for every new Xbox 360 release.'

RssItem.find(:all, 
             :order => 'updated_at', 
             :limit => 25,
             :conditions => 'critic_score IS NOT NULL'
             ).each do |row|
  puts "Writing #{row.title} to feed"
  item = Atom::Entry.new
  item.title = "#{row.critic_score}% #{row.title}"
  item.id = row.link
  item.links << Atom::Link.new(:href => row.link)
  item.authors << Atom::Author.new(:name => 'Metacritic')
  item.published = row.created_at
  item.updated = row.updated_at
  feed.updated = row.updated_at if not feed.updated or feed.updated < row.updated_at

  item.content = "<img src=\"#{row.image_url}\"><div>#{row.description}</div>"
  item.content.type = "html"
  feed << item
end
feed.updated = Time.now unless feed.updated

File.open(config[:destination], "w") do |f|
  f.write(feed)
end

