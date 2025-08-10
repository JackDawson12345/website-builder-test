class CreateWebsites < ActiveRecord::Migration[8.0]
  def change
    create_table :websites do |t|
      t.string :name
      t.string :domain_name
      t.json :content

      t.timestamps
    end
  end
end
