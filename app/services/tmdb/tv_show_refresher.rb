module Tmdb
  class TvShowRefresher
    ENDED_STATUSES = ["Ended", "Canceled"].freeze

    def initialize(client: nil)
      @client = client || Client.new
      @stats = { updated: 0, not_found: 0, errors: 0 }
      @last_log_time = Time.current
    end

    def refresh
      total = tv_shows_to_refresh.count
      Rails.logger.info "Found #{total} TV shows needing refresh"

      tv_shows_to_refresh.find_each.with_index do |tv_show, index|
        refresh_tv_show(tv_show)
        log_progress(index + 1, total)
      end

      @stats
    end

    def refresh_tv_show(tv_show)
      tmdb_id = find_tmdb_id(tv_show.tconst)

      if tmdb_id.nil?
        mark_as_not_found(tv_show)
        @stats[:not_found] += 1
        return
      end

      update_tv_show_data(tv_show, tmdb_id)
      @stats[:updated] += 1
    rescue Client::ApiError => e
      Rails.logger.warn "TMDB API error for #{tv_show.tconst}: #{e.message}"
      @stats[:errors] += 1
    rescue => e
      Rails.logger.error "Error refreshing TV show #{tv_show.tconst}: #{e.message}"
      @stats[:errors] += 1
    end

    private

    attr_reader :client

    # Priority order:
    # 1. Never updated (last_update NULL)
    # 2. Oldest updates (stale data)
    # 3. TV shows with preferred people (more likely to watch)
    # 4. Newest shows (recent releases more relevant)
    # 5. Higher vote count (more popular = more likely to watch)
    def tv_shows_to_refresh
      TitleTvTmdb
        .needs_update
        .joins("LEFT JOIN title_basics ON title_tv_tmdb.tconst = title_basics.tconst")
        .joins("LEFT JOIN title_ratings ON title_tv_tmdb.tconst = title_ratings.tconst")
        .select("title_tv_tmdb.*, " \
          "CASE WHEN EXISTS (SELECT 1 FROM title_principals " \
          "INNER JOIN my_preferences ON title_principals.nconst = my_preferences.nconst " \
          "WHERE title_principals.tconst = title_tv_tmdb.tconst) THEN 1 ELSE 0 END AS has_preferences")
        .order(
          Arel.sql("title_tv_tmdb.last_update ASC NULLS FIRST"),
          Arel.sql("has_preferences DESC"),
          Arel.sql("title_basics.start_year DESC NULLS LAST"),
          Arel.sql("title_ratings.num_votes DESC NULLS LAST")
        )
    end

    def log_progress(current, total)
      return if total.zero?

      now = Time.current
      if now - @last_log_time >= 30.seconds
        percentage = (current.to_f / total * 100).round(1)
        Rails.logger.info "TV show refresh progress: #{current}/#{total} (#{percentage}%) - #{@stats[:updated]} updated, #{@stats[:not_found]} not found, #{@stats[:errors]} errors"
        @last_log_time = now
      end
    end

    def find_tmdb_id(imdb_id)
      result = client.find_by_imdb_id(imdb_id)
      tv_results = result["tv_results"] || []
      tv_results.first&.dig("id")&.to_s
    end

    def update_tv_show_data(tv_show, tmdb_id)
      details = client.tv_show_details(tmdb_id)

      tv_show.update!(
        last_air_date: parse_date(details["last_air_date"]),
        next_air_date: extract_next_air_date(details),
        continuing: extract_continuing_status(details),
        languages: extract_languages(details),
        last_update: Time.current,
        tmdb_not_found: false
      )
    end

    def extract_next_air_date(details)
      next_episode = details["next_episode_to_air"]
      return nil unless next_episode

      parse_date(next_episode["air_date"])
    end

    def extract_continuing_status(details)
      status = details["status"]
      return nil if status.blank?

      !ENDED_STATUSES.include?(status)
    end

    def extract_languages(details)
      spoken_languages = details["spoken_languages"] || []

      if spoken_languages.any?
        spoken_languages
          .map { |l| l["iso_639_1"]&.downcase }
          .compact
          .sort
          .join(", ")
      elsif details["original_language"].present?
        details["original_language"].downcase
      end
    end

    def parse_date(date_string)
      return nil if date_string.blank?

      Date.parse(date_string)
    rescue ArgumentError
      nil
    end

    def mark_as_not_found(tv_show)
      tv_show.update!(last_update: Time.current, tmdb_not_found: true)
    end
  end
end
