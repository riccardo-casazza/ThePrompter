require "sqlite3"

module PlexDatabaseHelper
  def self.create_test_database(path)
    FileUtils.mkdir_p(File.dirname(path))
    File.delete(path) if File.exist?(path)

    db = SQLite3::Database.new(path)

    db.execute <<~SQL
      CREATE TABLE library_sections (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      )
    SQL

    db.execute <<~SQL
      CREATE TABLE metadata_items (
        id INTEGER PRIMARY KEY,
        library_section_id INTEGER NOT NULL,
        metadata_type INTEGER NOT NULL,
        title TEXT NOT NULL,
        original_title TEXT,
        year INTEGER,
        tags_collection TEXT
      )
    SQL

    db.execute <<~SQL
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY,
        tag TEXT NOT NULL
      )
    SQL

    db.execute <<~SQL
      CREATE TABLE taggings (
        id INTEGER PRIMARY KEY,
        metadata_item_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL
      )
    SQL

    db.close
    path
  end

  def self.populate_test_database(path)
    db = SQLite3::Database.new(path)

    # Insert library sections
    db.execute "INSERT INTO library_sections (id, name) VALUES (1, 'Movies')"
    db.execute "INSERT INTO library_sections (id, name) VALUES (2, 'TV Shows')"
    db.execute "INSERT INTO library_sections (id, name) VALUES (3, 'Music')"

    # Insert IMDb tags
    db.execute "INSERT INTO tags (id, tag) VALUES (1, 'imdb://tt0000001')"
    db.execute "INSERT INTO tags (id, tag) VALUES (2, 'imdb://tt0000002')"
    db.execute "INSERT INTO tags (id, tag) VALUES (3, 'imdb://tt0000003')"
    db.execute "INSERT INTO tags (id, tag) VALUES (4, 'imdb://tt0000004')"
    db.execute "INSERT INTO tags (id, tag) VALUES (5, 'genre://Action')" # Not IMDb, should be ignored

    # Insert metadata items
    # Movies (metadata_type: 1)
    db.execute "INSERT INTO metadata_items (id, library_section_id, metadata_type, title, original_title, year, tags_collection) VALUES (1, 1, 1, 'The Matrix', NULL, 1999, 'Sci-Fi Classics')"
    db.execute "INSERT INTO metadata_items (id, library_section_id, metadata_type, title, original_title, year, tags_collection) VALUES (2, 1, 1, 'Inception', 'Inception Original', 2010, NULL)"

    # TV Shows (metadata_type: 2)
    db.execute "INSERT INTO metadata_items (id, library_section_id, metadata_type, title, original_title, year, tags_collection) VALUES (3, 2, 2, 'Breaking Bad', NULL, 2008, 'Top Rated')"

    # Music artist (metadata_type: 8) - with IMDb tag (unusual but should be imported)
    db.execute "INSERT INTO metadata_items (id, library_section_id, metadata_type, title, original_title, year, tags_collection) VALUES (4, 3, 8, 'Hans Zimmer', NULL, NULL, NULL)"

    # Movie without IMDb tag (should be ignored)
    db.execute "INSERT INTO metadata_items (id, library_section_id, metadata_type, title, original_title, year, tags_collection) VALUES (5, 1, 1, 'No IMDb Tag Movie', NULL, 2020, NULL)"

    # Create taggings
    db.execute "INSERT INTO taggings (metadata_item_id, tag_id) VALUES (1, 1)" # The Matrix -> tt0000001
    db.execute "INSERT INTO taggings (metadata_item_id, tag_id) VALUES (2, 2)" # Inception -> tt0000002
    db.execute "INSERT INTO taggings (metadata_item_id, tag_id) VALUES (3, 3)" # Breaking Bad -> tt0000003
    db.execute "INSERT INTO taggings (metadata_item_id, tag_id) VALUES (4, 4)" # Hans Zimmer -> tt0000004
    db.execute "INSERT INTO taggings (metadata_item_id, tag_id) VALUES (5, 5)" # No IMDb Tag Movie -> genre tag (not IMDb)

    db.close
    path
  end
end
