class AddUniqueConstraintsToWebsitesTwo < ActiveRecord::Migration[8.0]
  def change
    # Add slug column if it doesn't exist (this might already be added by the previous migration)
    unless column_exists?(:websites, :slug)
      add_column :websites, :slug, :string
      add_index :websites, :slug, unique: true
    end
  end
end
