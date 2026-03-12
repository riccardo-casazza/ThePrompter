module Tmdb
  class ConsolidationJob
    include Sidekiq::Job
    sidekiq_options queue: :default

    def perform
      Rails.logger.info "Starting TMDB consolidation..."

      consolidator = Tmdb::Consolidator.new
      result = consolidator.consolidate

      Rails.logger.info "Movies: #{result[:movies][:added]} added, #{result[:movies][:removed]} removed"
      Rails.logger.info "TV Shows: #{result[:tv_shows][:added]} added, #{result[:tv_shows][:removed]} removed"
      Rails.logger.info "TMDB consolidation complete"

      result
    end
  end
end
