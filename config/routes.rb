Depstack::Application.routes.draw do
  post '/votes/:id' => 'votes#toggle', as: :vote
  get "/auth/:provider/callback" => "sessions#create"
  get "/signout" => "sessions#destroy", as: :signout
  get '/libraries/:manager/:name' => 'libraries#show', as: :library, constraints: { name: /.+/ }
  root "welcome#new"
end
