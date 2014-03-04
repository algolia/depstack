Depstack::Application.routes.draw do
  match '/vote/:id' => 'votes#toggle', as: :vote, via: [:post, :get]
  get "/auth/:provider/callback" => "sessions#create"
  get "/signout" => "sessions#destroy", as: :signout
  get '/libraries/:manager/:name' => 'libraries#show', as: :library, constraints: { name: /.+/ }
  root "welcome#new"
end
