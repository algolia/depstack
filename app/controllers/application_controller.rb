class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  layout 'lumen'

  include SessionsHelper

  protected
  def authenticate_user!
    return true if logged_in?
    redirect_to root_path
    return false
  end
end
