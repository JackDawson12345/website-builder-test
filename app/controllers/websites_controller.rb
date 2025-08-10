class WebsitesController < ApplicationController
  before_action :set_website, only: %i[ show edit update destroy ]

  # GET /websites
  def index
    @websites = Website.all
  end

  # GET /websites/1
  def show
  end

  # GET /websites/new
  def new
    @website = Website.new
  end

  # GET /websites/1/edit
  def edit
  end

  # POST /websites
  def create
    @website = Website.new(website_params)
    @website.user_id = current_user.id

    if @website.save
      redirect_to @website, notice: "Website was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /websites/1
  def update
    if @website.update(website_params)
      redirect_to @website, notice: "Website was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /websites/1
  def destroy
    @website.destroy!
    redirect_to websites_path, notice: "Website was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_website
      @website = Website.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def website_params
      params.expect(website: [ :name, :domain_name, :content, :user_id ])
    end
end
