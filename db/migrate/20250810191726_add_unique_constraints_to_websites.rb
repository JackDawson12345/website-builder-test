class AddUniqueConstraintsToWebsites < ActiveRecord::Migration[8.0]
  def change
    # Add unique index for website name (case insensitive)
    add_index :websites, "LOWER(name)", unique: true, name: "index_websites_on_lower_name"

    # Add unique index for domain name (case insensitive)
    add_index :websites, "LOWER(domain_name)", unique: true, name: "index_websites_on_lower_domain_name"

    # Add unique index for user_id to ensure one website per user
    add_index :websites, :user_id, unique: true, name: "index_websites_on_user_id_unique"

    # Add foreign key constraint
    add_foreign_key :websites, :users, on_delete: :cascade
  end
end