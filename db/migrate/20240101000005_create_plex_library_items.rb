class CreatePlexLibraryItems < ActiveRecord::Migration[7.1]
  def change
    create_table :plex_library_items, id: false do |t|
      t.string :tconst, limit: 15, null: false
      t.string :library_name, limit: 100, null: false
      t.integer :metadata_type, null: false
      t.string :title, limit: 512, null: false
      t.string :original_title, limit: 512
      t.integer :year, limit: 2
      t.string :collections, limit: 1024

      t.timestamps
    end

    add_index :plex_library_items, [:tconst, :library_name], unique: true
    add_index :plex_library_items, :tconst
    add_index :plex_library_items, :library_name
    add_index :plex_library_items, :metadata_type
    add_index :plex_library_items, :year
  end
end
