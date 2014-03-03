class Project < ActiveRecord::Base
  include AlgoliaSearch
  algoliasearch per_environment: true, auto_index: false, auto_remove: false do
    attribute :user, :name, :description, :language, :updated_at, :fork_count, :watcher_count
    add_attribute :libraries do
      libraries.map(&:name)
    end
    attributesForFaceting [:language, :libraries]
    attributesToIndex [:name, :user, :description, :language]
    customRanking ['desc(watcher_count)']
  end

  has_many :dependencies
  has_many :libraries, through: :dependencies

  scope :top, -> { order(watcher_count: :desc) }

  def load_dependencies!
    parse_dependencies.each do |dep|
      next if !dep[:name].is_a?(String) || dep[:name].blank?
      library = Library.get(dep[:name], dependency_manager)
      dependency = dependencies.detect { |d| d.library_id == library.id } || dependencies.build
      dependency.library_id = library.id
      dependency.environment = dep[:environment].to_s
      dependency.requirement = dep[:requirements]
      dependency.save!
    end
  end

  def parse_dependencies
    case dependency_manager
    when nil, ''
      []
    when 'rubygems'
      (Gemnasium::Parser::Gemfile.new(read_attribute :dependencies).dependencies rescue []).map do |dep|
        { name: dep.name, environment: dep.type, requirements: dep.requirements_list.first }
      end
    when 'npm'
      package = JSON.parse(read_attribute :dependencies)
      (package['dependencies'] || []).map { |name,requirement| { environment: :runtime, name: name, requirement: requirement }  } +
      (package['devDependencies'] || []).map { |name,requirement| { environment: :development, name: name, requirement: requirement }  }
    when 'bower'
      package = JSON.parse(read_attribute :dependencies)
      (package['dependencies'] || []).map { |name,requirement| { environment: :runtime, name: name, requirement: requirement }  }
    when 'composer'
      package = JSON.parse(read_attribute :dependencies)
      (package['require'] || []).map { |name,requirement| { environment: :runtime, name: name, requirement: requirement }  } +
      (package['require-dev'] || []).map { |name,requirement| { environment: :development, name: name, requirement: requirement }  }
    else
      raise "Unknown manager: #{dependency_manager}"
    end
  end

end
