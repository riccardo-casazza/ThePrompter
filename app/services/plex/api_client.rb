require "net/http"
require "json"

module Plex
  class ApiClient
    IMDB_GUID_REGEX = /imdb:\/\/(tt\d+)/

    def initialize(base_url:, token:)
      @base_url = base_url.chomp("/")
      @token = token
    end

    def libraries
      response = get("/library/sections")
      directories = response.dig("MediaContainer", "Directory") || []
      directories.map { |d| { key: d["key"], title: d["title"], type: d["type"] } }
    end

    def library_items(library_key)
      # includeGuids=1 is required to get external IDs (IMDB, TMDB, etc.)
      response = get("/library/sections/#{library_key}/all?includeGuids=1")
      metadata = response.dig("MediaContainer", "Metadata") || []
      metadata.filter_map { |item| parse_item(item) }
    end

    def all_items
      items = []
      libraries.each do |library|
        # Only process movie and show libraries
        next unless %w[movie show].include?(library[:type])

        library_items(library[:key]).each do |item|
          item[:library_name] = library[:title]
          items << item
        end
      end
      items
    end

    private

    attr_reader :base_url, :token

    def get(path)
      uri = URI("#{base_url}#{path}")
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      request["X-Plex-Token"] = token

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      raise "Plex API error: #{response.code} - #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def parse_item(item)
      # Extract IMDb ID from Guid array
      guids = item["Guid"] || []
      imdb_guid = guids.find { |g| g["id"]&.start_with?("imdb://") }
      return nil unless imdb_guid

      match = IMDB_GUID_REGEX.match(imdb_guid["id"])
      return nil unless match

      {
        tconst: match[1],
        metadata_type: item["type"] == "movie" ? 1 : 2, # 1 = movie, 2 = show (matching Plex DB convention)
        title: item["title"],
        original_title: item["originalTitle"],
        year: item["year"],
        collections: extract_collections(item)
      }
    end

    def extract_collections(item)
      collections = item["Collection"] || []
      collections.map { |c| c["tag"] }.join(", ").presence
    end
  end
end
