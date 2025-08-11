# config/initializers/friendly_id.rb

FriendlyId.defaults do |config|
  # Reserved words are words that FriendlyId will not use as candidates for slugs.
  # By default, FriendlyId will avoid generating slugs that conflict with common
  # controller names like "new", "edit", etc.
  config.use :reserved

  config.reserved_words = %w(new edit index session login logout users admin
                             stylesheets assets javascripts images)

  # This adds an option to treat reserved words as conflicts rather than exceptions.
  config.treat_reserved_as_conflict = true

  # By default, FriendlyId will use the :slugged module
  config.use :slugged
end