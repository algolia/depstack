class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_filter :setup_subdomain
  before_filter :setup_votes
  around_filter :back_rescue

  layout 'lumen'

  include SessionsHelper

  protected
  def authenticate_user!
    return true if logged_in?
    redirect_to :back, flash: { error: 'To up-vote, you first need to sign in!' }
    return false
  end

  def setup_votes
    @votes = logged_in? ? current_user.votes.map(&:library_id) : []
  end

  def setup_subdomain
    if request.get?
      case request.host_with_port
      when "www.depstack.io"
        redirect_to request.url.gsub('www.depstack.io', 'depstack.io'), :status => :moved_permanently
        return false
      when "www.depstack.com"
        redirect_to request.url.gsub('www.depstack.com', 'depstack.io'), :status => :moved_permanently
        return false
      when /^(.*)depstack\.com$/
        redirect_to request.url.gsub("#{$1}depstack.com", "#{$1}depstack.io"), :status => :moved_permanently
        return false
      end
    end
    @manager = case request.subdomain
    when 'ruby'
      :rubygems
    when 'go'
      :go
    when 'julia'
      :julia
    when 'atom'
      :apm
    when 'pypi'
      :pip
    when 'composer', 'php'
      :composer
    when 'js', 'node', 'npm'
      :npm
    else
      nil
    end
    return true
  end

  def back_rescue
    begin
      yield
    rescue ActionController::RedirectBackError
      redirect_to root_path
    end
  end

  DEFAULT_HIPCHAT_PARAMS = {
    color: :green, room: ENV['HIPCHAT_ROOM'], notify: false, format: 'html'
  }
  def hipchat_notify!(message, params = {})
    params = DEFAULT_HIPCHAT_PARAMS.merge(params)
    escaped_msg = (params[:mentions] ? "@#{params[:mentions].join(' @')} " : '') + (params[:format] == 'text' ? message : CGI::escapeHTML(message).to_s)
    HipChat::Client.new(ENV['HIPCHAT_API_TOKEN'])[params[:room]].send('rails', escaped_msg, color: params[:color], notify: params[:notify], message_format: params[:format])
  rescue
    # not fatal
  end
end
