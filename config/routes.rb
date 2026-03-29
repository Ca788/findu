Rails.application.routes.draw do
  # Health check
  get "/health", to: "health#show"
end
