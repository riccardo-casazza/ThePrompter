module Imdb
  class PersonalDataImportJob
    include Sidekiq::Job
    sidekiq_options queue: :default

    LOCK_KEY = "imdb:personal_data_import:lock".freeze
    LOCK_TTL = 30.minutes.to_i

    def perform(import_type = "all")
      # Prevent concurrent executions using Redis lock
      unless acquire_lock
        Rails.logger.info "PersonalDataImportJob already running, skipping..."
        return
      end

      begin
        Rails.logger.info "Starting personal data import (type: #{import_type})..."

        importer = PersonalDataImporter.new

        result = case import_type.to_sym
                 when :all
                   importer.import_all
                 when :preferences
                   { preferences: importer.import_preferences }
                 when :blacklist
                   { blacklist: importer.import_blacklist }
                 when :ratings
                   { ratings: importer.import_ratings }
                 else
                   raise ArgumentError, "Unknown import type: #{import_type}"
                 end

        log_result(result)
        result
      ensure
        release_lock
      end
    end

    private

    def acquire_lock
      Sidekiq.redis do |conn|
        conn.set(LOCK_KEY, jid, nx: true, ex: LOCK_TTL)
      end
    end

    def release_lock
      Sidekiq.redis do |conn|
        # Only release if we hold the lock
        conn.del(LOCK_KEY) if conn.get(LOCK_KEY) == jid
      end
    end

    def log_result(result)
      result.each do |type, stats|
        Rails.logger.info "#{type}: #{stats[:imported]} imported"
      end
    end
  end
end
