class LibrariesController < ApplicationController
  def show
    @library = Library.find_by!(manager_cd: Library.managers(params[:manager].to_s), name: params[:name])
  end

  def index
    @manager = params[:manager]
  end
end
