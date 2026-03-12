require "sqlite3"

module Plex
  class DatabaseReader
    IMDB_TAG_PREFIX = "imdb://tt".freeze

    # Query to get all items with IMDb tags across all libraries
    ITEMS_QUERY = <<~SQL.freeze
      SELECT
        mi.metadata_type,
        mi.title,
        mi.original_title,
        mi.year,
        mi.tags_collection,
        substr(t.tag, 8) as tconst,
        ls.name as library_name
      FROM metadata_items mi
      JOIN taggings mi2t ON mi2t.metadata_item_id = mi.id
      JOIN tags t ON mi2t.tag_id = t.id
      JOIN library_sections ls ON mi.library_section_id = ls.id
      WHERE t.tag LIKE 'imdb://tt%'
      ORDER BY ls.name, mi.metadata_type, mi.title
    SQL

    def initialize(db_path:)
      @db_path = db_path
    end

    def each_item(&block)
      raise ArgumentError, "Block required" unless block_given?
      raise "Plex database not found: #{db_path}" unless File.exist?(db_path)

      db = SQLite3::Database.new(db_path, readonly: true)
      db.results_as_hash = true

      begin
        db.execute(ITEMS_QUERY) do |row|
          yield normalize_row(row)
        end
      ensure
        db.close
      end
    end

    def items
      results = []
      each_item { |item| results << item }
      results
    end

    def libraries
      raise "Plex database not found: #{db_path}" unless File.exist?(db_path)

      db = SQLite3::Database.new(db_path, readonly: true)
      db.results_as_hash = true

      begin
        db.execute("SELECT DISTINCT name FROM library_sections ORDER BY name").map { |row| row["name"] }
      ensure
        db.close
      end
    end

    private

    attr_reader :db_path

    def normalize_row(row)
      {
        tconst: row["tconst"],
        library_name: row["library_name"],
        metadata_type: row["metadata_type"],
        title: row["title"],
        original_title: row["original_title"],
        year: row["year"],
        collections: row["tags_collection"]
      }
    end
  end
end
