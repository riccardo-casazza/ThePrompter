class TmdbRefreshJob
  include Sidekiq::Job
  sidekiq_options queue: :default

  # Runs hourly to refresh TMDB metadata for movies and TV shows
  # Movies and TV shows are refreshed in parallel

  def perform
    Rails.logger.info "Starting TMDB refresh..."

    batch = Sidekiq::Batch.new
    batch.description = "TMDB refresh (movies + TV shows)"
    batch.on(:success, "TmdbRefreshJob::Callbacks#complete")

    batch.jobs do
      Tmdb::MovieRefreshJob.perform_async
      Tmdb::TvShowRefreshJob.perform_async
    end

    Rails.logger.info "TMDB refresh batch started: #{batch.bid}"
  end

  class Callbacks
    def complete(status, options)
      Rails.logger.info "TMDB refresh complete!"
    end
  end
end
