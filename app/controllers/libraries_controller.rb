class LibrariesController < ApplicationController
  def show
    @library = Library.find_by!(name: params[:name])
  end
end
