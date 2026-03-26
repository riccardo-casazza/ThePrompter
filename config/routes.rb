Rails.application.routes.draw do
  root "home#index"

  resources :titles, only: [:index]

  get "health", to: proc { [200, {}, ["OK"]] }
end
