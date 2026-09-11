module Tmdb
  class MovieRefresher
    # Release types from TMDB API
    # 1 = Premiere, 2 = Theatrical (limited), 3 = Theatrical
    # 4 = Digital, 5 = Physical, 6 = TV
    THEATER_RELEASE_TYPES = [1, 2, 3].freeze
    HOME_RELEASE_TYPES = [4, 5, 6].freeze
    THEATER_COUNTRIES = %w[FR IT].freeze

    # Process this many movies per hourly run to avoid timeouts
    BATCH_SIZE = 1000

    # Retry configuration for connection errors
    MAX_CONNECTION_RETRIES = 2
    RETRY_DELAY_SECONDS = 5

    # Custom error for unrecoverable connection failures
    class ConnectionFailedError < StandardError; end

    def initialize(client: nil)
      @client = client || Client.new
      @stats = { updated: 0, not_found: 0, errors: 0 }
      @last_log_time = Time.current
      @connection_retry_count = 0
    end

    def refresh
      total_pending = with_connection_retry { TitleMovieTmdb.needs_update.count }
      batch = with_connection_retry { movies_to_refresh.limit(BATCH_SIZE).to_a }
      batch_size = batch.size

      Rails.logger.info "Found #{total_pending} movies needing refresh, processing batch of #{batch_size}"

      batch.each.with_index do |movie, index|
        refresh_movie(movie)
        log_progress(index + 1, batch_size)
      end

      Rails.logger.info "Batch complete: #{@stats[:updated]} updated, #{@stats[:not_found]} not found, #{@stats[:errors]} errors. Remaining: #{total_pending - batch_size}"

      @stats
    end

    def refresh_movie(movie)
      tmdb_id = find_tmdb_id(movie.tconst)

      if tmdb_id.nil?
        with_connection_retry { mark_as_not_found(movie) }
        @stats[:not_found] += 1
        return
      end

      with_connection_retry { update_movie_data(movie, tmdb_id) }
      @stats[:updated] += 1
    rescue Client::ApiError => e
      Rails.logger.warn "TMDB API error for #{movie.tconst}: #{e.message}"
      @stats[:errors] += 1
    rescue ConnectionFailedError
      # Re-raise connection failures to stop the job
      raise
    rescue => e
      Rails.logger.error "Error refreshing movie #{movie.tconst}: #{e.message}"
      @stats[:errors] += 1
    end

    private

    attr_reader :client

    # Priority order:
    # 1. Never updated (last_update NULL)
    # 2. Oldest updates (stale data)
    # 3. Newest movies (recent releases more relevant)
    # 4. Higher vote count (more popular = more likely to watch)
    def movies_to_refresh
      TitleMovieTmdb
        .needs_update
        .joins("LEFT JOIN title_basics ON title_movie_tmdb.tconst = title_basics.tconst")
        .joins("LEFT JOIN title_ratings ON title_movie_tmdb.tconst = title_ratings.tconst")
        .order(
          Arel.sql("title_movie_tmdb.last_update ASC NULLS FIRST"),
          Arel.sql("title_basics.start_year DESC NULLS LAST"),
          Arel.sql("title_ratings.num_votes DESC NULLS LAST")
        )
    end

    def log_progress(current, total)
      return if total.zero?

      now = Time.current
      if now - @last_log_time >= 30.seconds
        percentage = (current.to_f / total * 100).round(1)
        Rails.logger.info "Movie refresh progress: #{current}/#{total} (#{percentage}%) - #{@stats[:updated]} updated, #{@stats[:not_found]} not found, #{@stats[:errors]} errors"
        @last_log_time = now
      end
    end

    def find_tmdb_id(imdb_id)
      result = client.find_by_imdb_id(imdb_id)
      movie_results = result["movie_results"] || []
      movie_results.first&.dig("id")&.to_s
    end

    def update_movie_data(movie, tmdb_id)
      release_data = fetch_release_dates(tmdb_id)
      details_data = fetch_movie_details(tmdb_id)

      movie.update!(
        home_air_date: release_data[:home_air_date],
        theater_air_date_fr: release_data[:theater_air_date_fr],
        theater_air_date_it: release_data[:theater_air_date_it],
        languages: details_data[:languages],
        original_language: details_data[:original_language],
        production_countries: details_data[:production_countries],
        last_update: Time.current,
        tmdb_not_found: false
      )
    end

    def fetch_release_dates(tmdb_id)
      response = client.movie_release_dates(tmdb_id)
      results = response["results"] || []

      {
        home_air_date: extract_home_release_date(results),
        theater_air_date_fr: extract_theater_release_date(results, "FR"),
        theater_air_date_it: extract_theater_release_date(results, "IT")
      }
    end

    def extract_home_release_date(results)
      all_releases = results.flat_map { |r| r["release_dates"] || [] }
      home_releases = all_releases.select { |r| HOME_RELEASE_TYPES.include?(r["type"]) }

      return nil if home_releases.empty?

      earliest = home_releases.min_by { |r| r["release_date"] }
      parse_date(earliest["release_date"])
    end

    def extract_theater_release_date(results, country_code)
      country_result = results.find { |r| r["iso_3166_1"] == country_code }
      return nil unless country_result

      releases = country_result["release_dates"] || []
      theater_releases = releases.select { |r| THEATER_RELEASE_TYPES.include?(r["type"]) }

      return nil if theater_releases.empty?

      earliest = theater_releases.min_by { |r| r["release_date"] }
      parse_date(earliest["release_date"])
    end

    def fetch_movie_details(tmdb_id)
      response = client.movie_details(tmdb_id)

      {
        languages: extract_languages(response),
        original_language: response["original_language"]&.downcase,
        production_countries: extract_production_countries(response)
      }
    end

    def extract_production_countries(response)
      countries = response["production_countries"] || []
      return nil if countries.empty?

      countries.map { |c| c["iso_3166_1"] }.compact.join(", ")
    end

    def extract_languages(response)
      spoken_languages = response["spoken_languages"] || []

      if spoken_languages.any?
        spoken_languages
          .map { |l| l["iso_639_1"]&.downcase }
          .compact
          .sort
          .join(", ")
      elsif response["original_language"].present?
        response["original_language"].downcase
      end
    end

    def parse_date(date_string)
      return nil if date_string.blank?

      # TMDB returns dates like "2024-01-15T00:00:00.000Z" or "2024-01-15"
      Date.parse(date_string.split("T").first)
    rescue ArgumentError
      nil
    end

    def mark_as_not_found(movie)
      movie.update!(last_update: Time.current, tmdb_not_found: true)
    end

    def with_connection_retry
      retries = 0
      begin
        yield
      rescue PG::ConnectionBad, ActiveRecord::ConnectionNotEstablished => e
        retries += 1
        if retries <= MAX_CONNECTION_RETRIES
          Rails.logger.warn "Database connection error (attempt #{retries}/#{MAX_CONNECTION_RETRIES}): #{e.message}. Retrying in #{RETRY_DELAY_SECONDS}s..."
          sleep(RETRY_DELAY_SECONDS)
          ActiveRecord::Base.connection.reconnect!
          retry
        else
          Rails.logger.error "Database connection failed after #{MAX_CONNECTION_RETRIES} retries. Stopping job."
          raise ConnectionFailedError, "Database connection failed after #{MAX_CONNECTION_RETRIES} retries: #{e.message}"
        end
      end
    end
  end
end
