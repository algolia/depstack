class VotesController < ApplicationController
  before_filter :authenticate_user!

  def show
    @libraries = current_user.votes.order(created_at: :desc).map(&:library).compact
  end

  def toggle
    lib = Library.find(params[:id])
    vote = current_user.votes.find_by(library_id: lib.id)
    if vote.nil?
      vote = current_user.votes.create(library_id: lib.id)
      hipchat_notify! "#{current_user.login} voted for #{vote.library.name} (#{vote.library.manager})", color: :green
    else
      vote.destroy
    end
    if request.xhr?
      render nothing: true
    else
      redirect_to library_path(vote.library.manager, vote.library.name)
    end
  end

end
