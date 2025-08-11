class WebsitesController < ApplicationController
  before_action :authenticate_user!, except: [:show_by_subdomain, :debug_subdomain]
  before_action :set_website, only: %i[ show edit update destroy preview ]
  before_action :check_user_website_limit, only: %i[ new create ]

  # Debug method for development
  def debug_subdomain
    extracted_subdomain = extract_subdomain_from_host(request.host)
    render json: {
      full_host: request.host,
      rails_subdomain: request.subdomain,
      extracted_subdomain: extracted_subdomain,
      subdomain_present: request.subdomain.present?,
      subdomain_blank: request.subdomain.blank?,
      request_url: request.url,
      all_websites: Website.pluck(:slug, :name)
    }
  end

  # Redirect from subdomain edit to admin edit
  def redirect_to_admin_edit
    subdomain = extract_subdomain_from_host(request.host)
    website = Website.find_by(slug: subdomain)

    if website
      # Redirect to the admin edit page
      redirect_to edit_website_url(website, host: 'localhost', port: request.port),
                  status: :moved_permanently
    else
      # If website not found, redirect to main site
      redirect_to root_url(host: 'localhost', port: request.port),
                  alert: "Website not found"
    end
  end

  # Redirect from subdomain admin to main admin dashboard
  def redirect_to_admin
    subdomain = extract_subdomain_from_host(request.host)
    website = Website.find_by(slug: subdomain)

    if website
      # Redirect to the websites index (admin dashboard)
      redirect_to websites_url(host: 'localhost', port: request.port),
                  status: :moved_permanently
    else
      # If website not found, redirect to main site
      redirect_to root_url(host: 'localhost', port: request.port),
                  alert: "Website not found"
    end
  end

  # GET /websites
  def index
    @websites = current_user.website ? [current_user.website] : []
  end

  # GET /websites/uniteldirect (using slug) - Admin view
  def show
    # Ensure user can only view their own website
    redirect_to websites_path unless @website.user == current_user
  end

  # GET http://uniteldirect.localhost:3000 (subdomain routing) - Public view
  def show_by_subdomain
    # Extract subdomain manually since Rails doesn't detect it properly with .localhost
    subdomain = extract_subdomain_from_host(request.host)

    # Debug logging
    Rails.logger.info "=== SUBDOMAIN DEBUG ==="
    Rails.logger.info "Full host: #{request.host}"
    Rails.logger.info "Rails subdomain: '#{request.subdomain}'"
    Rails.logger.info "Extracted subdomain: '#{subdomain}'"
    Rails.logger.info "Request URL: #{request.url}"
    Rails.logger.info "======================="

    @website = Website.find_by(slug: subdomain)

    if @website.nil?
      Rails.logger.info "Website not found for subdomain: #{subdomain}"
      Rails.logger.info "Available slugs: #{Website.pluck(:slug)}"
      render_website_not_found
    else
      Rails.logger.info "Found website: #{@website.name} (#{@website.slug})"
      render_website_content
    end
  end

  # GET /websites/uniteldirect/preview - Preview for logged in users
  def preview
    # Ensure user can only preview their own website
    unless @website.user == current_user
      redirect_to websites_path, alert: "You can only preview your own website."
      return
    end

    render_website_content
  end

  # GET /websites/new
  def new
    @website = current_user.build_website
  end

  # GET /websites/uniteldirect/edit (using slug)
  def edit
    # Ensure user can only edit their own website
    redirect_to websites_path unless @website.user == current_user
  end

  # POST /websites
  def create
    @website = current_user.build_website(website_params)

    if @website.save
      redirect_to @website, notice: "Website was successfully created. You can view it at http://#{@website.slug}.localhost:3000"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /websites/uniteldirect (using slug)
  def update
    # Ensure user can only update their own website
    unless @website.user == current_user
      redirect_to websites_path, alert: "You can only edit your own website."
      return
    end

    if @website.update(website_params)
      redirect_to @website, notice: "Website was successfully updated. View it at http://#{@website.slug}.localhost:3000", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /websites/uniteldirect (using slug)
  def destroy
    # Ensure user can only delete their own website
    unless @website.user == current_user
      redirect_to websites_path, alert: "You can only delete your own website."
      return
    end

    @website.destroy!
    redirect_to websites_path, notice: "Website was successfully destroyed.", status: :see_other
  end

  private

  # Extract subdomain from host manually for .localhost domains
  def extract_subdomain_from_host(host)
    # Remove port if present
    host_without_port = host.split(':').first

    # Split by dots
    parts = host_without_port.split('.')

    # For patterns like "uniteldirect.localhost" -> return "uniteldirect"
    # For patterns like "localhost" -> return ""
    if parts.length >= 2 && parts.last == 'localhost'
      # Return everything except the last part (localhost)
      parts[0..-2].join('.')
    else
      # Fallback to Rails' built-in subdomain detection
      request.subdomain
    end
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_website
    @website = Website.friendly.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to websites_path, alert: "Website not found."
  end

  # Check if user already has a website before allowing new creation
  def check_user_website_limit
    if current_user.website.present?
      redirect_to current_user.website, alert: "You can only have one website. Edit your existing website instead."
    end
  end

  # Only allow a list of trusted parameters through.
  def website_params
    params.expect(website: [ :name, :domain_name, :content ])
  end

  def render_website_content
    # For now, we'll render a simple page. You can customize this based on your content structure
    render 'show_public', layout: 'website_public'
  end

  def render_website_not_found
    render 'not_found', layout: 'website_public', status: :not_found
  end
end