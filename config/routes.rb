require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  mount Sidekiq::Web => "/sidekiq"

  root "home#index"

  resources :titles, only: [:index]
  get "awards", to: "titles#awards"

  get "health", to: proc { [200, {}, ["OK"]] }
end
