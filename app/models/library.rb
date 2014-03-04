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

  def self.load!(manager, name, fast = false)
    manager_cd = Library.managers[manager.to_s]
    library = Library.find_or_initialize_by(manager_cd: manager_cd, name: name)
    return library if !library.new_record? && fast
    p(library) if library.new_record?
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
        library.homepage_uri = json['homepage']
        library.repository_uri = json['repository'] && (json['repository'].is_a?(Array) ? json['repository'].first : json['repository'])['url']
        last_version = json['dist-tags']['latest'] rescue 'N/A'
        library.load_dependencies! ((json['versions'][last_version] || json['versions'].first || {})['devDependencies'] || []).map { |k, v| { name: k, requirement: v, environment: :development } } + 
          ((json['versions'][last_version] || json['versions'].first || {})['dependencies'] || []).map { |k, v| { name: k, requirement: v, environment: :runtime } }
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
        # TODO: The metadata available for packages on PyPI does not include
        #       information about the dependencies.
        # library.load_dependencies!
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
      Dependency.new(source_id: id, destination_id: library.id, environment: dep[:environment], requirement: dep[:requirement])
    end
    save!
  end

end
