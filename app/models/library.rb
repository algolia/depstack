require 'open-uri'

class Library < ActiveRecord::Base
  include AlgoliaSearch
  algoliasearch per_environment: true, auto_index: false, auto_remove: false do
    attribute :name, :description, :downloads, :manager, :platform, :homepage_uri, :repository_uri, :score, :votes_count
    add_attribute :used_by do
      used_by.uniq(&:name).sort { |a,b| b.votes_count <=> a.votes_count }.first(5).map(&:name)
    end
    add_attribute :used_by_count do
      used_by.size
    end
    attributesForFaceting [:platform]
    tags do
      [manager.to_s]
    end
    attributesToIndex ['unordered(name)', 'unordered(description)', :homepage_uri]
    customRanking ['desc(score)', 'desc(used_by_count)']
  end

  has_many :dependencies, foreign_key: 'source_id', dependent: :destroy
  has_many :using, through: :dependencies, source: :destination

  has_many :requirements, class_name: 'Dependency', foreign_key: 'destination_id', dependent: :destroy
  has_many :used_by, through: :requirements, source: :source

  has_many :votes, dependent: :destroy
  has_many :users, through: :votes

  as_enum :manager, [:rubygems, :npm, :bower, :composer, :pip, :go]

  def score
    used_by.inject(votes_count) { |sum, lib| sum + lib.votes_count }
  end

  def top_requirements(limit)
    requirements.joins(:source).select('dependencies.*, libraries.votes_count AS votes_count').order('votes_count DESC').first(limit)
  end

  def github?
    uri = repository_uri || homepage_uri
    uri && uri['github.com']
  end

  def github_repository
    return nil if !github?
    (repository_uri || homepage_uri).scan(/github\.com\/([^\/]+)\/([^\/]+)/).first
  end

  def self.load!(manager, name, fast = false)
    manager_cd = Library.managers[manager.to_s]
    library = Library.find_or_initialize_by(manager_cd: manager_cd, name: name)
    return library if !library.new_record? && fast
    case manager_cd
    when Library.rubygems
      json = JSON.parse(open("http://rubygems.org/api/v1/gems/#{name}.json").read) rescue nil
      if json
        library.downloads = json['downloads']
        library.platform = json['platform']
        library.description = json['info']
        library.homepage_uri = json['homepage_uri']
        library.repository_uri = json['source_code_uri']
        library.load_dependencies! (json['dependencies']['development'] or []).map { |r| { name: r['name'], requirement: r['requirements'], environment: :development } } +
          (json['dependencies']['runtime'] or []).map { |r| { name: r['name'], requirement: r['requirements'], environment: :runtime } }
      end
    when Library.npm, Library.bower
      json = JSON.parse(open("https://registry.npmjs.org/#{name}").read) rescue nil
      if json
        library.downloads = 0
        library.platform = (json['versions'] || {}).detect { |version,spec| (spec['engines'] || {}).detect { |k,v| k['node'] } } ? 'node' : 'js' rescue 'js'
        library.description = json['description']
        library.homepage_uri = json['homepage'].is_a?(Array) ? json['homepage'].first : json['homepage']
        library.repository_uri = json['repository'] && (json['repository'].is_a?(Array) ? json['repository'].first : json['repository'])['url']
        last_version = json['dist-tags']['latest'] rescue nil
        last_version ||= json['versions'].try(:first).try(:first)
        if last_version
          devDependencies = (json['versions'][last_version] || json['versions'].first || {})['devDependencies'] rescue nil
          dependencies = (json['versions'][last_version] || json['versions'].first || {})['dependencies'] rescue nil
          library.load_dependencies! (devDependencies || {}).map { |k, v| { name: k, requirement: v, environment: :development } } + 
            (dependencies || {}).map { |k, v| { name: k, requirement: v, environment: :runtime } }
        end
      end
    when Library.composer
      json = JSON.parse(open("https://packagist.org/packages/#{name}.json").read) rescue nil
      if json
        library.downloads = json['package']['downloads'] && json['package']['downloads']['total']
        library.platform = 'php'
        library.description = json['package']['description']
        library.homepage_uri = nil
        library.repository_uri = json['package']['repository']
        version = (json['package']['versions']['dev-master'] || json['package']['versions'].first.last) rescue {}
        library.load_dependencies! (version['require'] || []).map { |k, v| { name: k, requirement: v, environment: :runtime } } +
          (version['require-dev'] || []).map { |k, v| { name: k, requirement: v, environment: :runtime } }
      end
    when Library.pip
      json = JSON.parse(open("https://pypi.python.org/pypi/#{name}/json").read) rescue nil
      if json
        library.downloads = json['info']['downloads']['last_month']
        library.platform = 'python'
        library.description = json['info']['summary']
        library.homepage_uri = json['info']['home_page']
        library.repository_uri = json['info']['project_url']
        if library.repository_uri.is_a?(Array)
          library.repository_uri = (library.repository_uri.first || '').split(',').last
        end
        # TODO: The metadata available for packages on PyPI does not include
        #       information about the dependencies.
        # library.load_dependencies!
      end
    when Library.go
      json = JSON.parse(open("http://go-search.org/api?action=package&id=#{CGI.escape name}").read) rescue nil
      if json
        library.downloads = json['StarCount']
        library.platform = 'go'
        library.description = json['Description']
        library.description = json['Synopsis'] if library.description.blank?
        library.homepage_uri = json['ProjectURL']
        library.load_dependencies! (json['Imports'] || []).map { |v| { name: v } }
      end
    else
      raise "Unknown manager: #{manager}"
    end
    library.save!
    library
  end

  def load_dependencies!(deps)
    save!
    self.dependencies = deps.map do |dep|
      library = Library.load!(manager, dep[:name], true)
      requirement = dep[:requirement]
      requirement = requirement['version'] if requirement.is_a?(Hash)
      Dependency.new(source_id: id, destination_id: library.id, environment: dep[:environment], requirement: requirement)
    end
    save!
  end

end
