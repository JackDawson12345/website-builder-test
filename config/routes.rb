Rails.application.routes.draw do
  devise_for :users

  get "up" => "rails/health#show", as: :rails_health_check

  # Debug route to test subdomain detection
  get "/debug_subdomain", to: "websites#debug_subdomain" if Rails.env.development?

  # Check if this is a subdomain request by looking at the host
  # For uniteldirect.localhost -> extract "uniteldirect"
  subdomain_constraint = ->(req) {
    host_without_port = req.host.split(':').first
    parts = host_without_port.split('.')
    # Return true if we have something like "uniteldirect.localhost"
    parts.length >= 2 && parts.last == 'localhost' && parts.first != 'localhost'
  }

  # Main domain constraint (just "localhost")
  main_domain_constraint = ->(req) {
    host_without_port = req.host.split(':').first
    host_without_port == 'localhost' || !subdomain_constraint.call(req)
  }

  # Subdomain routes (uniteldirect.localhost:3000)
  get "/", to: "websites#show_by_subdomain", constraints: subdomain_constraint, as: :subdomain_root

  # Main domain routes (localhost:3000)
  root "home#index", constraints: main_domain_constraint

  resources :websites do
    member do
      get :preview
    end
  end
end