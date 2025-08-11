Rails.application.routes.draw do
  devise_for :users

  get "up" => "rails/health#show", as: :rails_health_check

  # Debug route to test subdomain detection
  get "/debug_subdomain", to: "websites#debug_subdomain" if Rails.env.development?

  # Check if this is a subdomain request by looking at the host
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
  constraints subdomain_constraint do
    # Homepage route - must come first
    get "/", to: "websites#show_page", defaults: { page_slug: "/" }, as: :subdomain_root

    # Catch-all route for dynamic pages - must come last
    get "*page_slug", to: "websites#show_page", as: :subdomain_page
  end

  # Main domain routes (localhost:3000)
  root "home#index", constraints: main_domain_constraint

  resources :websites do
    member do
      get :preview
      # Preview specific pages
      get "preview/*page_slug", to: "websites#preview_page", as: :preview_page

      # Edit specific page content
      get "edit/:page_slug", to: "websites#edit_page", as: :edit_page
      patch "edit/:page_slug", to: "websites#update_page", as: :update_page
    end
  end
end