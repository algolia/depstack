module SessionsHelper
  def logged_in?
    !current_user.nil?
  end

  def current_user
    session[:user_id] and User.find(session[:user_id])
  end
end
