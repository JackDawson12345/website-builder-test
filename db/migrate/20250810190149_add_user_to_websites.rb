class AddUserToWebsites < ActiveRecord::Migration[8.0]
  def change
    add_column :websites, :user_id, :integer
  end
end
