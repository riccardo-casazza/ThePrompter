module Tmdb
  class Client
    BASE_URL = "https://api.themoviedb.org/3".freeze
    TIMEOUT = 10 # seconds

    class ApiError < StandardError; end
    class NotFoundError < ApiError; end
    class UnauthorizedError < ApiError; end
    class RateLimitError < ApiError; end

    def initialize(api_key: nil)
      @api_key = api_key || ENV.fetch("TMDB_API_KEY")
    end

    # Find TMDB ID from IMDb ID
    def find_by_imdb_id(imdb_id)
      response = get("/find/#{imdb_id}", external_source: "imdb_id")
      response
    end

    # Get movie release dates
    def movie_release_dates(tmdb_id)
      get("/movie/#{tmdb_id}/release_dates")
    end

    # Get movie details (for languages)
    def movie_details(tmdb_id)
      get("/movie/#{tmdb_id}")
    end

    # Get TV show details
    def tv_show_details(tmdb_id)
      get("/tv/#{tmdb_id}")
    end

    private

    attr_reader :api_key

    def get(path, params = {})
      # Apply rate limiting before making the request
      RateLimiter.throttle

      url = "#{BASE_URL}#{path}"
      params = params.merge(api_key: api_key)

      response = HTTParty.get(
        url,
        query: params,
        timeout: TIMEOUT,
        headers: { "Accept" => "application/json" }
      )

      handle_response(response)
    end

    def handle_response(response)
      case response.code
      when 200
        response.parsed_response
      when 401
        raise UnauthorizedError, "Invalid TMDB API key"
      when 404
        raise NotFoundError, "Resource not found"
      when 429
        raise RateLimitError, "TMDB rate limit exceeded"
      when 400..499
        raise ApiError, "Client error: #{response.code} - #{response.body}"
      when 500..599
        raise ApiError, "Server error: #{response.code}"
      else
        raise ApiError, "Unexpected response: #{response.code}"
      end
    end
  end
end
