class VotesController < ApplicationController
  before_filter :authenticate_user!

  def show
    @libraries = current_user.votes.order(created_at: :desc).map(&:library).compact
  end

  def toggle
    vote = current_user.votes.find_by(library_id: params[:id])
    if vote.nil?
      vote = current_user.votes.create(library_id: params[:id])
      hipchat_notify! "#{current_user.login} voted for #{vote.library.name} (#{vote.library.manager})", notify: true, color: :green
    else
      vote.destroy
    end
    redirect_to library_path(vote.library.manager, vote.library.name)
  end

end
