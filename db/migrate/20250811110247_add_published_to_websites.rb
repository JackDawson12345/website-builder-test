class AddPublishedToWebsites < ActiveRecord::Migration[8.0]
  def change
    add_column :websites, :published, :boolean, default: false, null: false

    # Add index for better performance when querying published websites
    add_index :websites, :published
  end
end