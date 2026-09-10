require "sidekiq/web"

Rails.application.routes.draw do
  mount Sidekiq::Web => "/sidekiq"

  root "home#index"

  resources :titles, only: [:index]

  get "health", to: proc { [200, {}, ["OK"]] }
end
