require 'open-uri'

class Library < ActiveRecord::Base
  include AlgoliaSearch
  algoliasearch per_environment: true, auto_index: false, auto_remove: false do
    attribute :name, :info, :downloads, :platform, :homepage_uri, :projects_watcher_count
    add_attribute :top_projects do
      projects.top.first(5).map do |project|
        { name: project.name, user: project.user }
      end
    end
    attributesForFaceting [:platform, 'top_projects.name']
    attributesToIndex [:name, :info, :homepage_uri]
    customRanking ['desc(projects_watcher_count)']
  end

  has_many :dependencies
  has_many :projects, through: :dependencies

  def projects_watcher_count
    projects.inject(0) { |sum, project| sum + project.watcher_count }
  end

  def github?
    homepage_uri && homepage_uri['github.com']
  end

  def github_repository
    return nil if !github?
    homepage_uri.scan(/github\.com\/([^\/]+)\/([^\/]+)/).first
  end

  def self.get(name, manager)
    library = Library.find_or_initialize_by(name: name)
    if library.new_record?
      case manager
      when 'rubygems'
        json = JSON.parse(open("http://rubygems.org/api/v1/gems/#{name}.json").read) rescue nil
        if json
          library.downloads = json['downloads']
          library.platform = json['platform']
          library.info = json['info']
          library.homepage_uri = json['homepage_uri']
        end
        library.save!
      when 'npm', 'bower'
        json = JSON.parse(open("https://registry.npmjs.org/#{name}").read) rescue nil
        if json
          library.downloads = 0
          library.platform = (json['versions'] || {}).detect { |version,spec| (spec['engines'] || {}).detect { |k,v| k['node'] } } ? 'node' : 'js'
          library.info = json['description']
          library.homepage_uri = json['homepage']
        end
        library.save!
      when 'composer'
        json = JSON.parse(open("https://packagist.org/packages/#{name}.json").read) rescue nil
        if json
          library.downloads = json['downloads'] && json['downloads']['total']
          library.platform = 'php'
          library.info = json['description']
          library.homepage_uri = json['repository']
        end
        library.save!
      else
        raise "Unknown manager: #{dependency_manager}"
      end
    end
    library
  end

end
