module Tmdb
  class MovieRefreshJob
    include Sidekiq::Job
    sidekiq_options queue: :default

    def perform
      Rails.logger.info "Starting TMDB movie refresh..."

      refresher = Tmdb::MovieRefresher.new
      stats = refresher.refresh

      Rails.logger.info "TMDB movie refresh complete: #{stats[:updated]} updated, #{stats[:not_found]} not found, #{stats[:errors]} errors"

      stats
    end
  end
end
