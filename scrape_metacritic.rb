#!/usr/bin/env ruby

require 'rubygems'
require 'rss/1.0'
require 'rss/2.0'
require 'rss/maker'
require 'open-uri'
require 'mechanize'
require 'activerecord'
require 'pp'

class MetacriticReview 
  attr_reader :title, :image_url, :critic_score, :description

  def initialize(url)
    agent = WWW::Mechanize.new
    page = agent.get(url)
    @image_url = page.search("//table[@id='scoretable']//img[@src]")[0]['src']
    score_xpath = "//table[@id='scoretable']//img[contains(@alt, 'Metascore:')]"
    @critic_score = page.search(score_xpath).attr('alt').gsub(/Metascore:\s*/i, '');
    @title = page.search("//table[@class='gameshead']//td")[0].text
    @description = page.search("//div[@id='midsection']/p").text    
  end
end

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
    not RssItem.valid_score?(self.critic_score)
  end
  
  def self.valid_score?(score)
    score.to_i > 0 and score.to_i <= 100
  end

  def self.normalize_link(link)
    link.gsub(/\?part=rss/, '')
  end

  def load_review
    agent = WWW::Mechanize.new
    page = agent.get(self.link)
    self.image_url = page.search("//table[@id='scoretable']//img[@src]")[0]['src']
    score_xpath = "//table[@id='scoretable']//img[contains(@alt, 'Metascore:')]"
    critic_score = page.search(score_xpath).attr('alt').gsub(/Metascore:\s*/i, '');
    self.critic_score = critic_score if RssItem.valid_score?(critic_score)
    self.title = page.search("//table[@class='gameshead']//td")[0].text
    self.description = page.search("//div[@id='midsection']/p").text
    self.save
  end

end

ActiveRecord::Base.establish_connection(
  :adapter  => 'mysql',
  :host     => 'localhost',
  :database => 'metacritic',
  :username => 'root',
  :password => '',
  :socket   => '/opt/local/var/run/mysql5/mysqld.sock'
)

SourceRss = 'http://www.metacritic.com/rss/games/xbox360.xml'
DestRss = "/tmp/xbox360.xml" 

RssItem.load_from_rss(SourceRss)

# Update reviews
RssItem.find(:all, 
             :conditions => "critic_score IS NULL"
             ).each do |row|
  if row.needs_update?
    puts "Loading review data for #{row.shortname}"
    row.load_review
  end
end

feed = RSS::Maker.make('2.0') do |m|
  m.channel.title = 'Metacritic.com: Xbox 360 Reviews'
  m.channel.link  = 'http://www.metacritic.com/rss/games/xbox360'
  m.channel.description = 'Metacritic Games compiles reviews from dozens of publications for every new Xbox 360 release.'

  RssItem.find(:all, 
               :order => 'date', 
               :limit => 25,
               :conditions => 'critic_score IS NOT NULL'
               ).each do |row|
    item = m.items.new_item
    item.title = "#{row.critic_score}% #{row.title}"
    item.link = row.link
    item.date = row.date
  end
end

File.open(DestRss, "w") do |f|
  f.write(feed)
end

