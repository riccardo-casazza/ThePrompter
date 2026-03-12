module Imdb
  class CreateIndexesJob
    include Sidekiq::Job

    sidekiq_options queue: :default, retry: 3

    # Creates indexes concurrently on a table after data import
    # This allows the table to be available for queries immediately after COPY
    def perform(table_name, indexes)
      Rails.logger.info "Creating indexes concurrently on #{table_name}..."

      conn = ActiveRecord::Base.connection

      indexes.each do |index_def|
        index_name = index_def["name"]
        columns = index_def["columns"]
        unique = index_def["unique"] || false

        Rails.logger.info "Creating index #{index_name} on #{table_name}(#{columns})..."

        unique_clause = unique ? "UNIQUE" : ""
        sql = "CREATE #{unique_clause} INDEX CONCURRENTLY IF NOT EXISTS #{index_name} ON #{table_name} (#{columns})"

        begin
          conn.execute(sql)
          Rails.logger.info "Index #{index_name} created successfully"
        rescue ActiveRecord::StatementInvalid => e
          # CONCURRENTLY can leave invalid indexes if it fails
          # Drop and retry without CONCURRENTLY as fallback
          Rails.logger.warn "Concurrent index creation failed: #{e.message}, retrying without CONCURRENTLY"
          conn.execute("DROP INDEX IF EXISTS #{index_name}")
          conn.execute("CREATE #{unique_clause} INDEX #{index_name} ON #{table_name} (#{columns})")
          Rails.logger.info "Index #{index_name} created (non-concurrent fallback)"
        end
      end

      Rails.logger.info "All indexes created on #{table_name}"
    end
  end
end
