class CreateTitleBasics < ActiveRecord::Migration[7.1]
  def change
    create_table :title_basics, id: false do |t|
      t.string :tconst, limit: 15, null: false, primary_key: true
      t.string :title_type, limit: 255, null: false
      t.string :original_title, limit: 512, null: false
      t.integer :start_year, limit: 2
      t.integer :runtime_minutes
      t.string :genres, limit: 255
      t.string :url, limit: 50

      t.timestamps
    end

    add_index :title_basics, :title_type
    add_index :title_basics, :start_year
    add_index :title_basics, :genres
  end
end
