#!/usr/bin/env ruby
require 'net/http'
require 'uri'
require 'date'
require 'json'
require 'rexml/document'

FEED_URL = 'https://nesbitt.io/feed.xml'
GITHUB_USERNAME = 'andrew'
README_PATH = 'README.md'

BLOG_START = '<!-- BLOG-POSTS:START -->'
BLOG_END = '<!-- BLOG-POSTS:END -->'
REPOS_START = '<!-- REPOS:START -->'
REPOS_END = '<!-- REPOS:END -->'

def fetch_feed
  uri = URI(FEED_URL)
  response = Net::HTTP.get_response(uri)
  abort "Failed to fetch blog feed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  REXML::Document.new(response.body)
end

def fetch_repos(username, limit: 10)
  uri = URI("https://api.github.com/users/#{username}/repos?type=public&sort=created&direction=desc&per_page=100")
  request = Net::HTTP::Get.new(uri)
  request['Accept'] = 'application/vnd.github+json'
  request['User-Agent'] = 'README-Updater'

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  abort "Failed to fetch repos: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

  repos = JSON.parse(response.body)
  abort "GitHub API error: #{repos['message']}" if repos.is_a?(Hash) && repos['message']

  repos
    .reject { |r| r['fork'] }
    .first(limit)
    .map { |r| { name: r['name'], url: r['html_url'], description: r['description'] } }
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
  posts.map { |post| "- [#{post[:title]}](#{post[:link]})" }.join("\n")
end

def format_repos(repos)
  repos.map do |repo|
    line = "- [#{repo[:name]}](#{repo[:url]})"
    line += " - #{repo[:description]}" if repo[:description] && !repo[:description].empty?
    line
  end.join("\n")
end

def update_section(content, start_marker, end_marker, new_content, heading)
  new_section = "#{start_marker}\n#{new_content}\n#{end_marker}"

  if content.include?(start_marker) && content.include?(end_marker)
    content.gsub(/#{Regexp.escape(start_marker)}.*#{Regexp.escape(end_marker)}/m, new_section)
  else
    content + "\n#{heading}\n\n#{new_section}\n"
  end
end

original_content = File.read(README_PATH)
content = original_content.dup

doc = fetch_feed
posts = parse_posts(doc)
content = update_section(content, BLOG_START, BLOG_END, format_posts(posts), '### Latest Blog Posts')
puts "Fetched #{posts.length} blog posts"

repos = fetch_repos(GITHUB_USERNAME)
content = update_section(content, REPOS_START, REPOS_END, format_repos(repos), '### Latest Repos')
puts "Fetched #{repos.length} repos"

if content == original_content
  puts "No changes to README"
else
  File.write(README_PATH, content)
  puts "Updated README"
end
