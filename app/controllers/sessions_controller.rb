class SessionsController < ApplicationController

  def create
    auth = request.env["omniauth.auth"]
    h = auth["extra"]["raw_info"]
    session[:user_id] = User.find_or_create_by!(id: h['id'], login: h['login'], email: h['email'], avatar_url: h['avatar_url'], name: h['name']).id
    redirect_to root_url
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_url
  end

end
