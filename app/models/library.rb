require 'open-uri'
require 'lingua/stemmer'

class Library < ActiveRecord::Base
  include AlgoliaSearch
  algoliasearch per_environment: true, auto_index: false, auto_remove: false do
    add_attribute :short_name do
      case manager_cd
      when Library.composer
        p = name.split('/')
        (p.length >= 2 ? p[1..-1] : p).join('/')
      when Library.go
        p = name.split('/')
        (p.length >= 3 ? p[2..-1] : p).join('/')
      else
        name
      end
    end
    attribute :name, :description, :downloads, :manager, :language, :homepage_uri, :repository_uri, :score, :votes_count
    add_attribute :used_by do
      used_by.uniq(&:name).sort { |a,b| b.votes_count <=> a.votes_count }.first(5).map(&:name)
    end
    add_attribute :used_by_count do
      used_by.size
    end
    add_attribute :category do
      predict_category
    end
    attributesForFaceting [:language, :category]
    tags do
      [manager.to_s]
    end
    attributesToIndex ['unordered(short_name)', 'unordered(description)', :language, 'unordered(homepage_uri)', 'unordered(repository_uri)']
    customRanking ['desc(score)', 'desc(used_by_count)', 'asc(name)']
  end

  has_many :dependencies, foreign_key: 'source_id', dependent: :destroy
  has_many :using, through: :dependencies, source: :destination

  has_many :requirements, class_name: 'Dependency', foreign_key: 'destination_id', dependent: :destroy
  has_many :used_by, through: :requirements, source: :source

  has_many :votes, dependent: :destroy
  has_many :users, through: :votes

  as_enum :manager, [:rubygems, :npm, :bower, :composer, :pip, :go, :julia, :apm]

  def score
    used_by.inject(votes_count) { |sum, lib| sum + lib.votes_count }
  end

  def language
    case platform
    when "ruby", "jruby"
      'Ruby'
    when 'go'
      'Go'
    when 'python'
      'Python'
    when 'php'
      'PHP'
    when 'js'
      'JavaScript'
    when 'node'
      'Node.js'
    when 'java'
      'Java'
    when 'julia'
      'Julia'
    when 'atom'
      'Atom'
    else
      nil
    end
  end

  def top_requirements(limit)
    requirements.joins(:source).select('dependencies.*, libraries.votes_count AS votes_count').order('votes_count DESC').first(limit)
  end

  GITHUB_REGEXP = /github\.com(?:\/|:)([^\/]+)\/([^\/.]+)(?:\.git)?/

  def github?
    uri = repository_uri || homepage_uri
    uri && uri.match(GITHUB_REGEXP)
  end

  def github_repository
    return nil if !github?
    (repository_uri || homepage_uri).scan(GITHUB_REGEXP).first
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
        library.description = json['Synopsis']
        library.description = json['Description'] if library.description.blank?
        library.homepage_uri = json['ProjectURL']
        library.load_dependencies! (json['Imports'] || []).map { |v| { name: v } }
      end
    when Library.apm
      json = JSON.parse(open("https://atom.io/api/packages/#{CGI.escape name}").read) rescue nil
      if json
        library.downloads = 0
        library.platform = 'atom'
        if json['metadata']
          library.description = json['metadata']['description']
          repository = json['metadata']['repository'] && (json['metadata']['repository'].is_a?(Array) ? json['metadata']['repository'].first : json['metadata']['repository'])
          library.repository_uri = repository.is_a?(Hash) ? repository['url'] : repository
          deps = (json['metadata']['dependencies'] || []).map do |k, v|
            apm_package = open("https://atom.io/api/packages/#{CGI.escape k}").read rescue false
            { name: k, requirement: v, manager: (apm_package ? :apm : :npm) }
          end
          library.load_dependencies! deps
        end
        library.repository_uri ||= json['repository']['url'] if json['repository']
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
      manager = dep[:manager] || self.manager
      library = Library.load!(manager, dep[:name], true)
      requirement = dep[:requirement]
      requirement = requirement['version'] if requirement.is_a?(Hash)
      Dependency.new(source_id: id, destination_id: library.id, environment: dep[:environment], requirement: requirement)
    end
    save!
  end

  CLASSIFICATION_THRESHOLD = -20
  CLASSIFICATION_MIN_WORDS = 5
  def predict_category
    return nil if description.blank?
    text = stem_without_stopwords(description)
    return nil if text.split(/\s+/).size < CLASSIFICATION_MIN_WORDS
    best = classifier.classifications(text).sort_by { |a| a[1] }.last
    best[1] > CLASSIFICATION_THRESHOLD ? best[0] : nil
  end

  private
  @@classifier = nil
  def classifier
    if @@classifier.nil?
      @@classifier = Classifier::Bayes.new
      JSON.parse(File.read(File.join(Rails.root, 'db', 'categories_model.json'))).each do |cat, values|
        @@classifier.add_category cat
        values.each do |v|
          @@classifier.train(cat, stem_without_stopwords(v))
        end
      end
    end
    @@classifier
  end

  STOP_WORDS = /(\b|[[:punct:]])(?:(?:a|an|s|is|and|are|as|at|be|but|by|has|have|for|if|in|into|is|it|no|not|of|on|or|such|the|that|their|then|there|these|they|this|to|was|will|with)(\b|[[:punct:]]))+/i
  def stem_without_stopwords(str)
    str && Lingua.stemmer(str.gsub(STOP_WORDS, '\1\2'), language: 'en')
  end
end
