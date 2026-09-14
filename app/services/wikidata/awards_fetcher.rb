require "net/http"
require "json"
require "uri"

module Wikidata
  class AwardsFetcher
    ENDPOINT = "https://query.wikidata.org/sparql".freeze
    USER_AGENT = "ThePrompter/1.0 (https://github.com/riccardofraguglia/ThePrompter) Ruby".freeze
    REQUEST_DELAY = 1.0 # seconds between requests

    # Wikidata Q-numbers for each award
    AWARDS = {
      oscar_best_picture: "Q102427",
      golden_globe_drama: "Q1011509",
      golden_globe_musical_comedy: "Q670282",
      golden_globe_foreign: "Q387380",
      golden_globe_animated: "Q878902",
      tiff_peoples_choice: "Q39087364",
      cannes_palme_dor: "Q179808",
      cannes_un_certain_regard: "Q17354954",
      venice_golden_lion: "Q209459",
      venice_grand_jury: "Q944480"
    }.freeze

    class FetchError < StandardError; end

    def fetch_all
      results = {}

      AWARDS.each do |column, qid|
        Rails.logger.info "Fetching #{column} winners (Q#{qid})..."
        imdb_ids = fetch_winners(qid)
        results[column] = imdb_ids
        Rails.logger.info "  Found #{imdb_ids.size} winners with IMDb IDs"
        sleep(REQUEST_DELAY) unless column == AWARDS.keys.last
      end

      update_database(results)
      results.transform_values(&:size)
    end

    def fetch_winners(award_qid)
      query = build_sparql_query(award_qid)
      response = execute_query(query)
      parse_imdb_ids(response)
    end

    private

    def build_sparql_query(award_qid)
      <<~SPARQL
        SELECT DISTINCT ?imdbId WHERE {
          ?film wdt:P166 wd:#{award_qid} .
          ?film wdt:P345 ?imdbId .
        }
      SPARQL
    end

    def execute_query(query)
      uri = URI(ENDPOINT)
      uri.query = URI.encode_www_form(query: query, format: "json")

      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/sparql-results+json"
      request["User-Agent"] = USER_AGENT

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 30
      http.read_timeout = 60

      response = http.request(request)

      case response.code.to_i
      when 200
        JSON.parse(response.body)
      when 429
        raise FetchError, "Rate limit exceeded. Retry after: #{response['Retry-After']}"
      else
        raise FetchError, "HTTP #{response.code}: #{response.message}"
      end
    end

    def parse_imdb_ids(response)
      bindings = response.dig("results", "bindings") || []
      bindings.map { |b| b.dig("imdbId", "value") }.compact.uniq
    end

    def update_database(results)
      # Collect all unique IMDb IDs
      all_imdb_ids = results.values.flatten.uniq

      # Filter to only IMDb IDs that exist in our database
      existing_tconsts = TitleBasic.where(tconst: all_imdb_ids).pluck(:tconst).to_set

      Rails.logger.info "Found #{existing_tconsts.size} matching titles in database out of #{all_imdb_ids.size} award winners"

      # Build records for upsert - each record must have all keys
      default_awards = AWARDS.keys.index_with { false }

      records = {}
      results.each do |column, imdb_ids|
        imdb_ids.each do |imdb_id|
          next unless existing_tconsts.include?(imdb_id)

          records[imdb_id] ||= { tconst: imdb_id, **default_awards }
          records[imdb_id][column] = true
        end
      end

      return if records.empty?

      # Upsert all records
      TitleAward.upsert_all(
        records.values,
        unique_by: :tconst,
        update_only: AWARDS.keys
      )

      Rails.logger.info "Upserted #{records.size} award records"
    end
  end
end
