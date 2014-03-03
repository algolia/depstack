Depstack::Application.routes.draw do
  get '/projects/:user/:name' => 'projects#show', as: :project, constraints: { name: /.+/ }
  get '/libraries/:name' => 'libraries#show', as: :library, constraints: { name: /.+/ }
  root "welcome#new"
end
