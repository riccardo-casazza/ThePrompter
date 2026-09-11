class ProductionRegionJob
  include Sidekiq::Job
  sidekiq_options queue: :default

  # Process in batches to avoid memory issues
  BATCH_SIZE = 5000

  def perform
    Rails.logger.info "Starting production region computation..."

    movie_stats = process_movies
    tv_stats = process_tv_shows

    Rails.logger.info "Production region computation complete. " \
                      "Movies: #{movie_stats[:updated]} updated, #{movie_stats[:skipped]} skipped. " \
                      "TV Shows: #{tv_stats[:updated]} updated, #{tv_stats[:skipped]} skipped."
  end

  private

  def process_movies
    stats = { updated: 0, skipped: 0 }

    TitleMovieTmdb.where.not(production_countries: nil).find_in_batches(batch_size: BATCH_SIZE) do |batch|
      updates = batch.filter_map do |movie|
        region = ProductionRegionMapper.region_for(
          production_countries: movie.production_countries,
          original_language: movie.original_language
        )

        if region && region != movie.production_region
          stats[:updated] += 1
          { tconst: movie.tconst, production_region: region }
        else
          stats[:skipped] += 1
          nil
        end
      end

      if updates.any?
        TitleMovieTmdb.upsert_all(updates, unique_by: :tconst, update_only: [:production_region])
      end
    end

    stats
  end

  def process_tv_shows
    stats = { updated: 0, skipped: 0 }

    TitleTvTmdb.where.not(production_countries: nil).find_in_batches(batch_size: BATCH_SIZE) do |batch|
      updates = batch.filter_map do |tv_show|
        region = ProductionRegionMapper.region_for(
          production_countries: tv_show.production_countries,
          original_language: tv_show.original_language
        )

        if region && region != tv_show.production_region
          stats[:updated] += 1
          { tconst: tv_show.tconst, production_region: region }
        else
          stats[:skipped] += 1
          nil
        end
      end

      if updates.any?
        TitleTvTmdb.upsert_all(updates, unique_by: :tconst, update_only: [:production_region])
      end
    end

    stats
  end
end
