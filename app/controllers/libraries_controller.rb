class LibrariesController < ApplicationController
  def show
    manager_cd = Library.managers(params[:manager].to_s)
    raise ActiveRecord::RecordNotFound.new("Manager not found") if manager_cd.nil?
    @library = Library.find_by!(manager_cd: manager_cd, name: params[:name])
  end

  def index
    @manager = params[:manager]
  end

  def graph
    @manager = params[:manager]
    manager_cd = Library.managers(params[:manager].to_s)
    raise ActiveRecord::RecordNotFound.new("Manager not found") if manager_cd.nil?
    if request.format.json?
      @libraries = Library.where(manager_cd: manager_cd).order(votes_count: :desc).includes(:dependencies).limit(100)
      nodes = []
      @libraries.each do |lib|
        ([lib] + lib.using).each do |d|
          nodes << { name: d.name }
        end
      end
      nodes.uniq!
      links = []
      @libraries.each do |lib|
        lib.dependencies.each do |dep|
          source_idx = nodes.find_index(name: dep.source.name)
          destination_idx = nodes.find_index(name: dep.destination.name)
          next if source_idx.nil? || destination_idx.nil?
          links << {
            source: source_idx,
            target: destination_idx,
            value: [dep.requirement, dep.environment].join(' ')
          }
        end
      end
      render json: { nodes: nodes, links: links }
      return
    end
  end
end
