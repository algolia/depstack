require 'open-uri'

class Library < ActiveRecord::Base
  include AlgoliaSearch
  algoliasearch per_environment: true, auto_index: false, auto_remove: false do
    attribute :name, :description, :downloads, :manager, :platform, :homepage_uri, :repository_uri, :score
    add_attribute :used_by do
      used_by.order(votes_count: :desc).first(5).map { |lib| { name: lib.name, manager: lib.manager } }
    end
    attributesForFaceting [:platform]
    tags do
      [manager.to_s]
    end
    attributesToIndex [:name, :description, :homepage_uri]
    customRanking ['desc(score)']
  end

  has_many :dependencies, foreign_key: 'source_id', dependent: :destroy
  has_many :using, through: :dependencies, source: :destination

  has_many :requirements, class_name: 'Dependency', foreign_key: 'destination_id', dependent: :destroy
  has_many :used_by, through: :requirements, source: :source

  has_many :votes, counter_cache: :votes_count, dependent: :destroy
  has_many :users, through: :votes

  as_enum :manager, [:rubygems, :npm, :bower, :composer, :pip]

  def score
    used_by.count
  end

  def github?
    uri = repository_uri || homepage_uri
    uri && uri['github.com']
  end

  def github_repository
    return nil if !github?
    (repository_uri || homepage_uri).scan(/github\.com\/([^\/]+)\/([^\/]+)/).first
  end

  def self.load!(manager, name)
    manager_cd = Library.managers[manager.to_s]
    library = Library.find_or_initialize_by(manager_cd: manager_cd, name: name)
    if library.new_record?
      case manager_cd
      when Library.rubygems
        json = JSON.parse(open("http://rubygems.org/api/v1/gems/#{name}.json").read) rescue nil
        if json
          library.downloads = json['downloads']
          library.platform = json['platform']
          library.description = json['info']
          library.homepage_uri = json['homepage_uri']
          library.repository_uri = json['source_code_uri']
        end
      when Library.npm, Library.bower
        json = JSON.parse(open("https://registry.npmjs.org/#{name}").read) rescue nil
        if json
          library.downloads = 0
          library.platform = (json['versions'] || {}).detect { |version,spec| (spec['engines'] || {}).detect { |k,v| k['node'] } } ? 'node' : 'js' rescue 'js'
          library.description = json['description']
          library.homepage_uri = json['homepage']
          library.repository_uri = json['repository'] && json['repository']['url']
        end
      when Library.composer
        json = JSON.parse(open("https://packagist.org/packages/#{name}.json").read) rescue nil
        if json
          library.downloads = json['package']['downloads'] && json['package']['downloads']['total']
          library.platform = 'php'
          library.description = json['package']['description']
          library.homepage_uri = nil
          library.repository_uri = json['package']['repository']
        end
      when Library.pip
        json = JSON.parse(open("https://pypi.python.org/pypi/#{name}/json").read) rescue nil
        if json
          library.downloads = json['info']['downloads']['last_month']
          library.platform = 'python'
          library.description = json['info']['summary']
          library.homepage_uri = json['info']['home_page']
          library.repository_uri = json['info']['project_url']
        end
      else
        raise "Unknown manager: #{manager}"
      end
    end
    p(library) if library.new_record?
    library.save!
    library
  end

end
