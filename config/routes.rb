Rails.application.routes.draw do
  # Health check
  get "/health", to: "health#show"

  devise_for :users, skip: :all

  namespace :api do
    namespace :v1 do
      devise_scope :user do
        post "login", to: "sessions#create"
        delete "logout", to: "sessions#destroy"
      end

      resource :user, only: [:show], controller: "user"
      resource :organization, only: [:show], controller: "organization"
    end
  end
end
