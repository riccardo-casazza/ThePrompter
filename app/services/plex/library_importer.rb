module Plex
  class LibraryImporter
    BATCH_SIZE = 10_000
    TABLE_NAME = "plex_library_items".freeze
    STAGING_TABLE = "plex_library_items_staging".freeze

    # Factory method to create importer with appropriate backend
    def self.create
      if ENV["PLEX_URL"].present? && ENV["PLEX_TOKEN"].present?
        new(client: ApiClient.new(base_url: ENV["PLEX_URL"], token: ENV["PLEX_TOKEN"]))
      elsif ENV["PLEX_DB_PATH"].present?
        new(reader: DatabaseReader.new(db_path: ENV["PLEX_DB_PATH"]))
      else
        raise "Plex not configured. Set PLEX_URL and PLEX_TOKEN for API access, or PLEX_DB_PATH for direct database access."
      end
    end

    def initialize(client: nil, reader: nil)
      raise ArgumentError, "Must provide either client or reader" unless client || reader

      @client = client
      @reader = reader
      @imported_count = 0
    end

    def import
      Rails.logger.info "Starting Plex library import..."

      begin
        create_staging_table
        import_items_to_staging
        swap_tables
        Rails.logger.info "Import complete: #{@imported_count} items imported"
        { imported: @imported_count }
      ensure
        cleanup_staging_table
      end
    end

    def libraries
      if @client
        @client.libraries.map { |l| l[:title] }
      else
        @reader.libraries
      end
    end

    private

    def create_staging_table
      Rails.logger.info "Creating staging table #{STAGING_TABLE}..."
      conn = ActiveRecord::Base.connection

      conn.execute("DROP TABLE IF EXISTS #{STAGING_TABLE}")
      conn.execute(<<~SQL)
        CREATE UNLOGGED TABLE #{STAGING_TABLE} (
          tconst VARCHAR(15) NOT NULL,
          library_name VARCHAR(100) NOT NULL,
          metadata_type INTEGER NOT NULL,
          title VARCHAR(512) NOT NULL,
          original_title VARCHAR(512),
          year SMALLINT,
          collections VARCHAR(1024),
          created_at TIMESTAMP NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP NOT NULL DEFAULT NOW()
        )
      SQL
    end

    def import_items_to_staging
      Rails.logger.info "Importing items to staging table..."
      batch = []
      now = Time.current

      each_item do |item|
        batch << build_record(item, now)

        if batch.size >= BATCH_SIZE
          insert_batch_to_staging(batch)
          batch = []
        end
      end

      insert_batch_to_staging(batch) if batch.any?
      Rails.logger.info "Staging import complete: #{@imported_count} items"
    end

    def insert_batch_to_staging(records)
      return if records.empty?

      conn = ActiveRecord::Base.connection
      values = records.map do |r|
        "(#{conn.quote(r[:tconst])}, #{conn.quote(r[:library_name])}, #{r[:metadata_type]}, " \
        "#{conn.quote(r[:title])}, #{conn.quote(r[:original_title])}, #{r[:year] || 'NULL'}, " \
        "#{conn.quote(r[:collections])}, NOW(), NOW())"
      end.join(", ")

      conn.execute(<<~SQL)
        INSERT INTO #{STAGING_TABLE} (tconst, library_name, metadata_type, title, original_title, year, collections, created_at, updated_at)
        VALUES #{values}
      SQL

      @imported_count += records.size
      Rails.logger.info "Imported #{@imported_count} items..." if (@imported_count % 50_000).zero?
    end

    def swap_tables
      Rails.logger.info "Swapping tables atomically..."
      conn = ActiveRecord::Base.connection

      conn.execute(<<~SQL)
        BEGIN;
        DROP TABLE IF EXISTS #{TABLE_NAME};
        ALTER TABLE #{STAGING_TABLE} RENAME TO #{TABLE_NAME};
        COMMIT;
      SQL

      Rails.logger.info "Table swap complete, creating indexes..."

      # Create indexes (Plex table is small enough to do synchronously)
      conn.execute("CREATE UNIQUE INDEX index_plex_library_items_on_tconst_and_library_name ON #{TABLE_NAME} (tconst, library_name)")
      conn.execute("CREATE INDEX index_plex_library_items_on_tconst ON #{TABLE_NAME} (tconst)")
      conn.execute("CREATE INDEX index_plex_library_items_on_library_name ON #{TABLE_NAME} (library_name)")
      conn.execute("CREATE INDEX index_plex_library_items_on_metadata_type ON #{TABLE_NAME} (metadata_type)")
      conn.execute("CREATE INDEX index_plex_library_items_on_year ON #{TABLE_NAME} (year)")

      Rails.logger.info "Index creation complete"
    end

    def cleanup_staging_table
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{STAGING_TABLE}")
    rescue StandardError => e
      Rails.logger.warn "Failed to cleanup staging table: #{e.message}"
    end

    def each_item(&block)
      if @client
        @client.all_items.each(&block)
      else
        @reader.each_item(&block)
      end
    end

    def build_record(item, timestamp)
      {
        tconst: item[:tconst],
        library_name: item[:library_name],
        metadata_type: item[:metadata_type],
        title: item[:title],
        original_title: item[:original_title],
        year: item[:year],
        collections: item[:collections],
        created_at: timestamp,
        updated_at: timestamp
      }
    end
  end
end
