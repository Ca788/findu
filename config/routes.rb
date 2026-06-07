Rails.application.routes.draw do
  # Health check
  get "/health", to: "health#show"

  devise_for :users, skip: :all

  # Named route required by Devise mailer template (edit_user_password_url).
  # The link in the email points here; the frontend should intercept and
  # call PATCH /api/v1/password with the token.
  devise_scope :user do
    get "users/password/edit", to: "api/v1/passwords#update", as: :edit_user_password
  end

  namespace :api do
    namespace :v1 do
      devise_scope :user do
        post "login", to: "sessions#create"
        delete "logout", to: "sessions#destroy"
      end

      resource :user, only: [:show, :create, :update], controller: "user"
      resource :password, only: [:create, :update], controller: "passwords"

      resources :artifacts, only: [:index, :show, :create]

      namespace :inbound do
        resources :messages, only: [:create]
      end

      namespace :financial do
        resources :categories,   only: [:index, :show, :create, :update, :destroy]
        resources :transactions, only: [:index, :show, :create, :update, :destroy]
        resources :budgets,      only: [:index, :show, :create, :update, :destroy] do
          collection do
            get :current
          end
        end

        resource :summary, only: [:show], controller: "summary"
      end

      namespace :chat do
        resources :conversations, only: [:index, :show, :create, :destroy] do
          resources :messages, only: [:index, :show, :create]
        end
      end
    end
  end
end
