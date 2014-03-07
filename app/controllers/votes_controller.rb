class VotesController < ApplicationController
  before_filter :authenticate_user!

  def show
    @libraries = current_user.votes.order(created_at: :desc).map(&:library)
  end

  def toggle
    vote = current_user.votes.find_by(library_id: params[:id])
    if vote.nil?
      vote = current_user.votes.create(library_id: params[:id])
    else
      vote.destroy
    end
    redirect_to library_path(vote.library.manager, vote.library.name)
  end

end
