class ProjectsController < ApplicationController
  def show
    @project = Project.find_by!(user: params[:user], name: params[:name])
  end
end
