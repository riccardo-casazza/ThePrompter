module Imdb
  class TitlePrincipalsImporter
    INCLUDED_CATEGORIES = %w[
      actor
      actress
      director
      writer
      composer
    ].freeze

    # TSV column indices (0-based)
    TCONST_IDX = 0
    ORDERING_IDX = 1
    NCONST_IDX = 2
    CATEGORY_IDX = 3
    JOB_IDX = 4
    CHARACTERS_IDX = 5

    TABLE_NAME = "title_principals".freeze
    STAGING_TABLE = "title_principals_staging".freeze

    def initialize(file_path, truncate: true)
      @file_path = file_path
      @truncate = truncate
      @imported_count = 0
      @skipped_count = 0
    end

    def import
      Rails.logger.info "Starting title.principals import from #{file_path}"

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
          category = row[CATEGORY_IDX]

          unless INCLUDED_CATEGORIES.include?(category)
            @skipped_count += 1
            next
          end

          # Normalize actress to actor
          category = "actor" if category == "actress"

          out.puts [
            row[TCONST_IDX],
            row[ORDERING_IDX],
            row[NCONST_IDX],
            category
          ].join("\t")

          @imported_count += 1
          Rails.logger.info "Filtered #{@imported_count} records..." if (@imported_count % 1_000_000).zero?
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
          tconst VARCHAR(15) NOT NULL,
          ordering SMALLINT NOT NULL,
          nconst VARCHAR(15) NOT NULL,
          category VARCHAR(50) NOT NULL,
          created_at TIMESTAMP NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP NOT NULL DEFAULT NOW()
        )
      SQL
    end

    def copy_to_staging(filtered_path)
      Rails.logger.info "Starting COPY to staging table..."

      sql = <<~SQL
        COPY #{STAGING_TABLE} (tconst, ordering, nconst, category)
        FROM STDIN WITH (FORMAT text, DELIMITER E'\\t')
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
        { "name" => "index_title_principals_on_tconst_and_ordering", "columns" => "tconst, ordering", "unique" => true },
        { "name" => "index_title_principals_on_category", "columns" => "category" },
        { "name" => "index_title_principals_on_nconst", "columns" => "nconst" },
        { "name" => "index_title_principals_on_tconst", "columns" => "tconst" }
      ])
    end

    def cleanup_staging_table
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{STAGING_TABLE}")
    rescue StandardError => e
      Rails.logger.warn "Failed to cleanup staging table: #{e.message}"
    end
  end
end
