class CreateMyPreferences < ActiveRecord::Migration[7.1]
  def change
    create_table :my_preferences, id: false do |t|
      t.string :nconst, limit: 15, null: false
      t.string :primary_name, limit: 255, null: false
      t.string :category, limit: 50, null: false

      t.timestamps
    end

    add_index :my_preferences, [:nconst, :category], unique: true
    add_index :my_preferences, :category
  end
end
