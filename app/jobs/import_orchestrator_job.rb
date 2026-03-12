class ImportOrchestratorJob
  include Sidekiq::Job
  sidekiq_options queue: :default

  # Workflow (runs daily at 3 AM):
  # Phase 1: title_basics + title_principals + plex_library + personal_data (parallel)
  # Phase 2: title_ratings (depends on title_basics)
  # Phase 3: tmdb_consolidation (depends on title_basics)
  #
  # TMDB refresh runs separately via TmdbRefreshJob (hourly)

  def perform
    Rails.logger.info "Starting import orchestration..."

    phase1_batch = Sidekiq::Batch.new
    phase1_batch.description = "Phase 1: Import title_basics, title_principals, plex_library, and personal_data"
    phase1_batch.on(:success, "ImportOrchestratorJob::Callbacks#phase1_complete")

    phase1_batch.jobs do
      Imdb::TitleBasicsImportJob.perform_async
      Imdb::TitlePrincipalsImportJob.perform_async
      Plex::LibraryImportJob.perform_async
      Imdb::PersonalDataImportJob.perform_async
    end

    Rails.logger.info "Phase 1 batch started: #{phase1_batch.bid}"
  end

  class Callbacks
    def phase1_complete(status, options)
      Rails.logger.info "Phase 1 complete. Starting Phase 2..."

      phase2_batch = Sidekiq::Batch.new
      phase2_batch.description = "Phase 2: Import title_ratings"
      phase2_batch.on(:success, "ImportOrchestratorJob::Callbacks#phase2_complete")

      phase2_batch.jobs do
        Imdb::TitleRatingsImportJob.perform_async
      end

      Rails.logger.info "Phase 2 batch started: #{phase2_batch.bid}"
    end

    def phase2_complete(status, options)
      Rails.logger.info "Phase 2 complete. Starting Phase 3..."

      phase3_batch = Sidekiq::Batch.new
      phase3_batch.description = "Phase 3: TMDB consolidation"
      phase3_batch.on(:success, "ImportOrchestratorJob::Callbacks#phase3_complete")

      phase3_batch.jobs do
        Tmdb::ConsolidationJob.perform_async
      end

      Rails.logger.info "Phase 3 batch started: #{phase3_batch.bid}"
    end

    def phase3_complete(status, options)
      Rails.logger.info "Import orchestration complete!"
    end
  end
end
