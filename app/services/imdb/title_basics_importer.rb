module Imdb
  class TitleBasicsImporter
    IMDB_URL_BASE = "https://www.imdb.com/title/".freeze

    EXCLUDED_TITLE_TYPES = %w[
      tvEpisode
      tvSpecial
      video
      videoGame
      tvPilot
    ].freeze

    # TSV column indices (0-based)
    TCONST_IDX = 0
    TITLE_TYPE_IDX = 1
    PRIMARY_TITLE_IDX = 2
    ORIGINAL_TITLE_IDX = 3
    IS_ADULT_IDX = 4
    START_YEAR_IDX = 5
    END_YEAR_IDX = 6
    RUNTIME_MINUTES_IDX = 7
    GENRES_IDX = 8

    TABLE_NAME = "title_basics".freeze
    STAGING_TABLE = "title_basics_staging".freeze

    def initialize(file_path, truncate: true)
      @file_path = file_path
      @truncate = truncate
      @imported_count = 0
      @skipped_count = 0
    end

    def import
      Rails.logger.info "Starting title.basics import from #{file_path}"

      begin
        filtered_file = prepare_filtered_file
        create_staging_table
        copy_to_staging(filtered_file)
        swap_tables
        Rails.logger.info "Import complete: #{@imported_count} imported, #{@skipped_count} skipped"
        { imported: @imported_count, skipped: @skipped_count }
      ensure
        File.delete(filtered_file) if filtered_file && File.exist?(filtered_file)
        cleanup_staging_table
      end
    end

    private

    attr_reader :file_path, :truncate

    def prepare_filtered_file
      filtered_path = "#{file_path}.filtered.csv"
      Rails.logger.info "Filtering data to #{filtered_path}..."

      File.open(filtered_path, "w") do |out|
        File.foreach(file_path).with_index do |line, index|
          if index.zero?
            next
          end

          row = line.chomp.split("\t")
          title_type = row[TITLE_TYPE_IDX]

          if EXCLUDED_TITLE_TYPES.include?(title_type)
            @skipped_count += 1
            next
          end

          tconst = row[TCONST_IDX]
          out.puts [
            tconst,
            title_type,
            escape_copy_value(row[ORIGINAL_TITLE_IDX]),
            null_or_value(row[START_YEAR_IDX]),
            null_or_value(row[RUNTIME_MINUTES_IDX]),
            null_or_value(row[GENRES_IDX]),
            "#{IMDB_URL_BASE}#{tconst}"
          ].join("\t")

          @imported_count += 1
          Rails.logger.info "Filtered #{@imported_count} records..." if (@imported_count % 500_000).zero?
        end
      end

      Rails.logger.info "Filtering complete: #{@imported_count} records to import"
      filtered_path
    end

    def create_staging_table
      Rails.logger.info "Creating staging table #{STAGING_TABLE}..."
      conn = ActiveRecord::Base.connection

      conn.execute("DROP TABLE IF EXISTS #{STAGING_TABLE}")
      conn.execute(<<~SQL)
        CREATE UNLOGGED TABLE #{STAGING_TABLE} (
          tconst VARCHAR(15) PRIMARY KEY,
          title_type VARCHAR(255) NOT NULL,
          original_title VARCHAR(512) NOT NULL,
          start_year SMALLINT,
          runtime_minutes INTEGER,
          genres VARCHAR(255),
          url VARCHAR(50),
          created_at TIMESTAMP NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP NOT NULL DEFAULT NOW()
        )
      SQL
    end

    def copy_to_staging(filtered_path)
      Rails.logger.info "Starting COPY to staging table..."

      sql = <<~SQL
        COPY #{STAGING_TABLE} (tconst, title_type, original_title, start_year, runtime_minutes, genres, url)
        FROM STDIN WITH (FORMAT text, DELIMITER E'\\t', NULL '\\N')
      SQL

      conn = ActiveRecord::Base.connection.raw_connection
      conn.copy_data(sql) do
        File.foreach(filtered_path) do |line|
          conn.put_copy_data(line)
        end
      end

      Rails.logger.info "COPY to staging complete"
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

      Rails.logger.info "Table swap complete, enqueueing index creation..."

      # Create indexes concurrently in background
      Imdb::CreateIndexesJob.perform_async(TABLE_NAME, [
        { "name" => "index_title_basics_on_genres", "columns" => "genres" },
        { "name" => "index_title_basics_on_start_year", "columns" => "start_year" },
        { "name" => "index_title_basics_on_title_type", "columns" => "title_type" }
      ])
    end

    def cleanup_staging_table
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{STAGING_TABLE}")
    rescue StandardError => e
      Rails.logger.warn "Failed to cleanup staging table: #{e.message}"
    end

    def escape_copy_value(value)
      return "\\N" if value.nil? || value == "\\N" || value.empty?
      value.gsub("\\", "\\\\").gsub("\t", "\\t").gsub("\n", "\\n").gsub("\r", "\\r")
    end

    def null_or_value(value)
      return "\\N" if value.nil? || value == "\\N" || value.empty?
      value
    end
  end
end
