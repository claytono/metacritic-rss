#!/usr/bin/env ruby

require 'rubygems'
require 'rss/1.0'
require 'rss/2.0'
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

ActiveRecord::Base.establish_connection(
  :adapter  => 'mysql',
  :host     => 'localhost',
  :database => 'metacritic',
  :username => 'root',
  :password => '',
)

source = 'http://www.metacritic.com/rss/games/xbox360.xml'
content = ""
open(source) do |s| content = s.read end
rss = RSS::Parser.parse(content, false)
rss.items.each do |item| 
  review = MetacriticReview.new(item.link)
  puts "#{item.title} is rated #{review.critic_score}"
end
