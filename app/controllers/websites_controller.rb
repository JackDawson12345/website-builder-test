class WebsitesController < ApplicationController
  before_action :authenticate_user!, except: [:debug_subdomain, :show_page]
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

  # GET /websites
  def index
    @websites = current_user.website ? [current_user.website] : []
  end

  # GET /websites/uniteldirect (using slug) - Admin view
  def show
    # Ensure user can only view their own website
    redirect_to websites_path unless @website.user == current_user
  end

  # NEW: Handle dynamic page routing for subdomains
  def show_page
    # Extract subdomain manually since Rails doesn't detect it properly with .localhost
    subdomain = extract_subdomain_from_host(request.host)

    # Get the page slug from params (defaults to "/" for homepage)
    page_slug = params[:page_slug] || "/"
    page_slug = "/#{page_slug}" unless page_slug.start_with?("/")

    # Debug logging
    Rails.logger.info "=== PAGE ROUTING DEBUG ==="
    Rails.logger.info "Full host: #{request.host}"
    Rails.logger.info "Extracted subdomain: '#{subdomain}'"
    Rails.logger.info "Requested page slug: '#{page_slug}'"
    Rails.logger.info "=========================="

    @website = Website.find_by(slug: subdomain)

    if @website.nil?
      Rails.logger.info "Website not found for subdomain: #{subdomain}"
      render_website_not_found
      return
    end

    # Find the specific page in the website's content
    @page = find_page_by_slug(@website, page_slug)

    if @page.nil?
      Rails.logger.info "Page not found: #{page_slug} for website: #{@website.name}"
      render_page_not_found(page_slug)
    else
      Rails.logger.info "Found page: #{@page['Name']} (#{@page['Slug']})"
      render_website_page
    end
  end

  # GET /websites/uniteldirect/preview - Preview for logged in users
  def preview
    # Ensure user can only preview their own website
    unless @website.user == current_user
      redirect_to websites_path, alert: "You can only preview your own website."
      return
    end

    # Default to homepage for preview
    @page = find_page_by_slug(@website, "/")
    render_website_page
  end

  # Preview specific pages for logged in users
  def preview_page
    @website = Website.friendly.find(params[:id])

    # Ensure user can only preview their own website
    unless @website.user == current_user
      redirect_to websites_path, alert: "You can only preview your own website."
      return
    end

    page_slug = params[:page_slug] || "/"
    page_slug = "/#{page_slug}" unless page_slug.start_with?("/")

    @page = find_page_by_slug(@website, page_slug)

    if @page.nil?
      redirect_to preview_website_path(@website), alert: "Page not found: #{page_slug}"
    else
      render_website_page
    end
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

  def edit_page
    @website = Website.friendly.find(params[:id])

    # Ensure user can only edit their own website
    unless @website.user == current_user
      redirect_to websites_path, alert: "You can only edit your own website."
      return
    end

    # Convert page_slug parameter back to proper slug format
    page_slug_param = params[:page_slug]
    @page_slug = page_slug_param == 'home' ? '/' : "/#{page_slug_param}"

    # Find the specific page
    @page = find_page_by_slug(@website, @page_slug)

    if @page.nil?
      redirect_to website_path(@website), alert: "Page not found: #{@page_slug}"
      return
    end

    # Set page title for breadcrumb
    @page_title = @page['Name']
  end

  # PATCH /websites/uniteldirect/edit/about-us
  def update_page
    @website = Website.friendly.find(params[:id])

    # Ensure user can only update their own website
    unless @website.user == current_user
      redirect_to websites_path, alert: "You can only edit your own website."
      return
    end

    # Convert page_slug parameter back to proper slug format
    page_slug_param = params[:page_slug]
    @page_slug = page_slug_param == 'home' ? '/' : "/#{page_slug_param}"

    # Find the specific page
    @page = find_page_by_slug(@website, @page_slug)

    if @page.nil?
      redirect_to website_path(@website), alert: "Page not found: #{@page_slug}"
      return
    end

    # Update the page content in the JSON structure
    if update_page_content(@website, @page_slug, params[:page_content])
      if @website.save
        redirect_to website_path(@website),
                    notice: "#{@page['Name']} content updated successfully!"
      else
        @page_title = @page['Name']
        render :edit_page, status: :unprocessable_entity
      end
    else
      @page_title = @page['Name']
      flash.now[:alert] = "Failed to update page content."
      render :edit_page, status: :unprocessable_entity
    end
  end

  private

  def update_page_content(website, page_slug, new_content)
    return false unless website.content.is_a?(Hash) && website.content['pages'].is_a?(Array)

    # Find and update the specific page
    page_found = false
    website.content['pages'].each do |page|
      if page['Slug'] == page_slug
        page['content'] = new_content || ''
        page_found = true
        break
      end
    end

    page_found
  end

  # Convert slug to URL parameter format for routing
  def slug_to_param(slug)
    return 'home' if slug == '/'
    slug.gsub('/', '')
  end

  # Convert URL parameter back to slug format
  def param_to_slug(param)
    return '/' if param == 'home'
    "/#{param}"
  end

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

  # Find a page by its slug in the website's content
  def find_page_by_slug(website, slug)
    return nil unless website.content.is_a?(Hash) && website.content['pages'].is_a?(Array)

    website.content['pages'].find { |page| page['Slug'] == slug }
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

  # Add this method to your WebsitesController class
  def process_page_params(params)
    return {} unless params[:pages].present?

    pages = []

    params[:pages].each do |index, page_data|
      next unless page_data[:Name].present? && page_data[:Slug].present?

      # Ensure slug starts with /
      slug = page_data[:Slug]
      slug = "/#{slug}" unless slug.start_with?('/')

      pages << {
        "Name" => page_data[:Name],
        "Slug" => slug,
        "content" => page_data[:content] || ""
      }
    end

    { "pages" => pages }
  end

  # Update the website_params method
  def website_params
    permitted_params = params.expect(website: [ :name, :domain_name, :content, pages: {} ])

    # If pages are provided, process them and update content
    if permitted_params[:pages].present?
      # Store as Hash, not JSON string - Rails will handle JSON conversion
      permitted_params[:content] = process_page_params(permitted_params)
      permitted_params.delete(:pages)
    elsif permitted_params[:content].present? && permitted_params[:content].is_a?(String)
      # Parse JSON string if it's coming from the hidden field
      begin
        permitted_params[:content] = JSON.parse(permitted_params[:content])
      rescue JSON::ParserError
        # If parsing fails, leave as is
      end
    end

    permitted_params
  end

  def render_website_page
    render 'show_public', layout: 'website_public'
  end

  def render_website_not_found
    render 'not_found', layout: 'website_public', status: :not_found
  end

  def render_page_not_found(page_slug)
    @page_slug = page_slug
    render 'page_not_found', layout: 'website_public', status: :not_found
  end
end