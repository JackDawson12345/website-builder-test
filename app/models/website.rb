class Website < ApplicationRecord
  extend FriendlyId
  friendly_id :domain_base, use: :slugged

  belongs_to :user

  # Validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :domain_name, presence: true, uniqueness: { case_sensitive: false }
  validates :user_id, uniqueness: true # Ensures one website per user
  validates :slug, uniqueness: true, presence: true

  # Custom validation for domain format
  validate :valid_domain_format

  # Callbacks
  before_validation :set_slug, on: [:create, :update]

  # Helper methods for working with pages
  def pages
    return [] unless content.is_a?(Hash) && content['pages'].is_a?(Array)
    content['pages']
  end

  def pages_sorted_by_position
    return [] unless content.is_a?(Hash) && content['pages'].is_a?(Array)
    content['pages'].sort_by { |page| (page['position'] || 999).to_i }
  end

  def find_page_by_slug(slug)
    pages.find { |page| page['Slug'] == slug }
  end

  def homepage
    find_page_by_slug('/') || pages_sorted_by_position.first
  end

  def has_pages?
    pages.any?
  end

  def page_slugs
    pages.map { |page| page['Slug'] }.compact
  end

  def page_slugs_by_position
    pages_sorted_by_position.map { |page| page['Slug'] }.compact
  end

  def page_names
    pages.map { |page| page['Name'] }.compact
  end

  def page_names_by_position
    pages_sorted_by_position.map { |page| page['Name'] }.compact
  end

  # Get all nested pages under a parent slug
  def child_pages(parent_slug)
    return [] if parent_slug == '/'

    pages.select do |page|
      page['Slug'].start_with?("#{parent_slug}/") &&
        page['Slug'] != parent_slug
    end
  end

  # Get parent page slug for a given slug
  def parent_page_slug(slug)
    return nil if slug == '/'

    parts = slug.split('/').reject(&:empty?)
    return '/' if parts.length <= 1

    parent_parts = parts[0..-2]
    "/#{parent_parts.join('/')}"
  end

  # Check if a slug exists in the pages
  def page_exists?(slug)
    pages.any? { |page| page['Slug'] == slug }
  end

  # Get the next available position number
  def next_page_position
    return 1 if pages.empty?

    max_position = pages.map { |page| (page['position'] || 0).to_i }.max
    max_position + 1
  end

  # Update page positions to be sequential
  def normalize_page_positions!
    return false unless content.is_a?(Hash) && content['pages'].is_a?(Array)

    sorted_pages = pages_sorted_by_position
    sorted_pages.each_with_index do |page, index|
      page['position'] = index + 1
    end

    self.content = { 'pages' => sorted_pages }
    true
  end

  # Find page by position
  def find_page_by_position(position)
    pages.find { |page| page['position'] == position.to_i }
  end

  # Get navigation menu items in order
  def navigation_items
    pages_sorted_by_position.map do |page|
      {
        name: page['Name'],
        slug: page['Slug'],
        position: page['position'] || 999
      }
    end
  end

  private

  def valid_domain_format
    return if domain_name.blank?

    # Remove protocol if present
    clean_domain = domain_name.gsub(/^https?:\/\//, '')

    # Basic domain format validation
    domain_regex = /\A(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}\z/

    unless clean_domain.match?(domain_regex)
      errors.add(:domain_name, 'must be a valid domain format (e.g., example.com)')
    end

    # Additional check for common invalid patterns
    if clean_domain.include?('..') || clean_domain.start_with?('.') || clean_domain.end_with?('.')
      errors.add(:domain_name, 'contains invalid characters or format')
    end

    # Check for minimum length
    if clean_domain.length < 4 # minimum like a.co
      errors.add(:domain_name, 'is too short')
    end
  end

  def domain_base
    return nil if domain_name.blank?

    # Remove protocol if present
    clean_domain = domain_name.gsub(/^https?:\/\//, '')

    # Extract the main part before the first dot
    # For uniteldirect.co.uk -> uniteldirect
    # For uniteldirect.com -> uniteldirect
    # For subdomain.uniteldirect.com -> subdomain
    main_part = clean_domain.split('.').first

    # Clean up the main part to make it URL-friendly
    main_part&.downcase&.gsub(/[^a-z0-9\-_]/, '')
  end

  def set_slug
    if domain_name_changed? || slug.blank?
      base_slug = domain_base
      return if base_slug.blank?

      # Check if this slug already exists for another website
      counter = 1
      potential_slug = base_slug

      while Website.where(slug: potential_slug).where.not(id: self.id).exists?
        potential_slug = "#{base_slug}-#{counter}"
        counter += 1
      end

      self.slug = potential_slug
    end
  end

  def should_generate_new_friendly_id?
    domain_name_changed? || slug.blank?
  end
end