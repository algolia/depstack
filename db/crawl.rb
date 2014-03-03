#! /usr/bin/env ruby

require File.expand_path File.join(__FILE__, '../../config/environment')

require 'csv'
require 'httpclient'
require 'json'

if ARGV.length != 1
  $stderr << "usage: #{File.basename __FILE__} /path/to/export.csv\n"
  exit 1
end

clnt = HTTPClient.new
CSV.parse(File.read(ARGV[0]).gsub('\\"', '""'), headers: true) do |row|
  next if Project.where(user: row['user']).where(name: row['name']).first
  row['dependency_manager'] = 'npm'
  row['dependencies'] = JSON.parse(clnt.get_content("https://raw.github.com/#{row['user']}/#{row['name']}/master/package.json")).to_json rescue nil
  if row['dependencies'].nil?
    row['dependency_manager'] = 'rubygems'
    row['dependencies'] = clnt.get_content("https://raw.github.com/#{row['user']}/#{row['name']}/master/Gemfile") rescue nil
    if row['dependencies'].nil?
      row['dependency_manager'] = 'bower'
      row['dependencies'] = JSON.parse(clnt.get_content("https://raw.github.com/#{row['user']}/#{row['name']}/master/bower.json")).to_json rescue nil
      if row['dependencies'].nil?
        row['dependency_manager'] = 'composer'
        row['dependencies'] = JSON.parse(clnt.get_content("https://raw.github.com/#{row['user']}/#{row['name']}/master/composer.json")).to_json rescue nil
        if row['dependencies'].nil?
          row['dependency_manager'] = nil
        end
      end
    end
  end
  attributes = row.to_hash
  attributes.delete 'url'
  Project.create! attributes
end
