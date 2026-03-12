module Tmdb
  class TvShowRefreshJob
    include Sidekiq::Job
    sidekiq_options queue: :default

    def perform
      Rails.logger.info "Starting TMDB TV show refresh..."

      refresher = Tmdb::TvShowRefresher.new
      stats = refresher.refresh

      Rails.logger.info "TMDB TV show refresh complete: #{stats[:updated]} updated, #{stats[:not_found]} not found, #{stats[:errors]} errors"

      stats
    end
  end
end
