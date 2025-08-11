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