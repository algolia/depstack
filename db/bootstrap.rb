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
  manager = Library.npm
  spec = JSON.parse(clnt.get_content("https://raw.github.com/#{row['user']}/#{row['name']}/master/package.json")).to_json rescue nil
  if spec.nil?
    manager = Library.rubygems
    spec = clnt.get_content("https://raw.github.com/#{row['user']}/#{row['name']}/master/Gemfile") rescue nil
    if spec.nil?
      manager = Library.bower
      spec = JSON.parse(clnt.get_content("https://raw.github.com/#{row['user']}/#{row['name']}/master/bower.json")).to_json rescue nil
      if spec.nil?
        manager = Library.composer
        spec = JSON.parse(clnt.get_content("https://raw.github.com/#{row['user']}/#{row['name']}/master/composer.json")).to_json rescue nil
        if spec.nil?
          manager = Library.pip
          spec = clnt.get_content("https://raw.github.com/#{row['user']}/#{row['name']}/master/setup.py") rescue nil
          if spec.nil?
            manager = nil
          end
        end
      end
    end
  end
  next if manager.nil?
  deps = case manager
  when Library.rubygems
    (Gemnasium::Parser::Gemfile.new(spec).dependencies rescue []).map do |dep|
      { name: dep.name, environment: dep.type, requirement: dep.requirements_list.first }
    end
  when Library.npm
    (spec['dependencies'] || []).map { |name,requirement| { environment: :runtime, name: name, requirement: requirement }  } +
    (spec['devDependencies'] || []).map { |name,requirement| { environment: :development, name: name, requirement: requirement }  }
  when Library.bower
    (spec['dependencies'] || []).map { |name,requirement| { environment: :runtime, name: name, requirement: requirement }  }
  when Library.composer
    (spec['require'] || []).map { |name,requirement| { environment: :runtime, name: name, requirement: requirement }  } +
    (spec['require-dev'] || []).map { |name,requirement| { environment: :development, name: name, requirement: requirement }  }
  when Library.pip
    # FIXME: parse setup.py?
  else
    raise "Unknown manager: #{manager}"
  end
  p deps
end
