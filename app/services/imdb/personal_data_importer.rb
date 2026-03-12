module Imdb
  class PersonalDataImporter
    # IMDb list URLs - configure via environment or settings
    PREFERENCE_LISTS = {
      actor: ENV.fetch("IMDB_ACTORS_LIST_URL", "https://www.imdb.com/list/ls561367354"),
      writer: ENV.fetch("IMDB_WRITERS_LIST_URL", "https://www.imdb.com/list/ls561367143"),
      director: ENV.fetch("IMDB_DIRECTORS_LIST_URL", "https://www.imdb.com/list/ls561367616")
    }.freeze

    BLACKLIST_URL = ENV.fetch("IMDB_BLACKLIST_URL", "https://www.imdb.com/list/ls561616843")
    RATINGS_USER_ID = ENV.fetch("IMDB_USER_ID", "ur36872000")

    def initialize(scraper: nil)
      @scraper = scraper || ListScraper.new
    end

    def import_all
      {
        preferences: import_preferences,
        blacklist: import_blacklist,
        ratings: import_ratings
      }
    end

    def import_preferences
      Rails.logger.info "Importing favorite persons..."

      all_persons = []

      PREFERENCE_LISTS.each do |category, url|
        Rails.logger.info "Scraping #{category} list: #{url}"
        persons = @scraper.scrape_persons_list(url, category.to_s)
        Rails.logger.info "Found #{persons.size} #{category}s"
        all_persons.concat(persons)
      end

      # Truncate and import
      MyPreference.delete_all

      now = Time.current
      records = all_persons.map do |person|
        {
          nconst: person[:nconst],
          primary_name: person[:name],
          category: person[:category],
          created_at: now,
          updated_at: now
        }
      end

      MyPreference.upsert_all(records, unique_by: [:nconst, :category]) if records.any?

      { imported: records.size }
    end

    def import_blacklist
      Rails.logger.info "Importing blacklist from: #{BLACKLIST_URL}"

      tconsts = @scraper.scrape_titles_list(BLACKLIST_URL)
      Rails.logger.info "Found #{tconsts.size} blacklisted titles"

      # Truncate and import
      BlacklistedTitle.delete_all

      now = Time.current
      records = tconsts.map do |tconst|
        {
          tconst: tconst,
          created_at: now,
          updated_at: now
        }
      end

      BlacklistedTitle.upsert_all(records, unique_by: :tconst) if records.any?

      { imported: records.size }
    end

    def import_ratings
      Rails.logger.info "Exporting ratings for user: #{RATINGS_USER_ID}"

      cookies = {
        "ubid-main" => ENV.fetch("IMDB_UBID_COOKIE", ""),
        "at-main" => ENV.fetch("IMDB_AT_COOKIE", "")
      }

      exporter = RatingsExporter.new(
        user_id: RATINGS_USER_ID,
        cookies: cookies
      )

      ratings = exporter.export
      Rails.logger.info "Exported #{ratings.size} ratings"

      # Truncate and import
      MyRating.delete_all

      now = Time.current
      records = ratings.map do |rating|
        {
          tconst: rating[:tconst],
          rating: rating[:rating],
          created_at: now,
          updated_at: now
        }
      end

      MyRating.upsert_all(records, unique_by: :tconst) if records.any?

      { imported: records.size }
    end
  end
end
