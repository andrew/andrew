#!/usr/bin/env ruby
require 'net/http'
require 'uri'
require 'date'
require 'rexml/document'

FEED_URL = 'https://nesbitt.io/feed.xml'
README_PATH = 'README.md'
START_MARKER = '<!-- BLOG-POSTS:START -->'
END_MARKER = '<!-- BLOG-POSTS:END -->'

def fetch_feed
  uri = URI(FEED_URL)
  response = Net::HTTP.get(uri)
  REXML::Document.new(response)
end

def parse_posts(doc, limit: 10)
  posts = []
  doc.elements.each('feed/entry') do |entry|
    break if posts.length >= limit

    title = entry.elements['title']&.text
    link = entry.elements['link']&.attributes['href']
    published = entry.elements['published']&.text

    next unless title && link

    date = Date.parse(published).strftime('%Y-%m-%d') if published
    posts << { title: title, link: link, date: date }
  end
  posts
end

def format_posts(posts)
  lines = posts.map do |post|
    "- [#{post[:title]}](#{post[:link]})"
  end
  lines.join("\n")
end

def update_readme(posts_markdown)
  content = File.read(README_PATH)

  new_section = "#{START_MARKER}\n#{posts_markdown}\n#{END_MARKER}"

  if content.include?(START_MARKER) && content.include?(END_MARKER)
    content.gsub!(/#{Regexp.escape(START_MARKER)}.*#{Regexp.escape(END_MARKER)}/m, new_section)
  else
    content += "\n### Latest Blog Posts\n\n#{new_section}\n"
  end

  File.write(README_PATH, content)
end

doc = fetch_feed
posts = parse_posts(doc)
posts_markdown = format_posts(posts)
update_readme(posts_markdown)

puts "Updated README with #{posts.length} blog posts"
