Depstack::Application.routes.draw do
  match '/vote/:id' => 'votes#toggle', as: :vote, via: [:post, :get]
  get '/votes' => 'votes#show', as: :votes
  get "/auth/:provider/callback" => "sessions#create"
  get "/signout" => "sessions#destroy", as: :signout
  get '/libraries/:manager/:name' => 'libraries#show', as: :library, constraints: { name: /.+/ }
  get '/popular/:manager' => 'libraries#index', as: :popular
  get '/graph/:manager' => 'libraries#graph', as: :graph
  root "welcome#new"
end
