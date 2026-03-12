class TitleMovieTmdb < ApplicationRecord
  self.table_name = "title_movie_tmdb"
  self.primary_key = "tconst"

  belongs_to :title_basic, foreign_key: :tconst, primary_key: :tconst, optional: true

  # Retry found movies every 7 days, not found movies every 30 days
  scope :needs_update, -> {
    where(last_update: nil)
      .or(where(tmdb_not_found: false).where("last_update < ?", 7.days.ago))
      .or(where(tmdb_not_found: true).where("last_update < ?", 30.days.ago))
  }
  scope :with_home_release, -> { where.not(home_air_date: nil) }
  scope :with_theater_release_fr, -> { where.not(theater_air_date_fr: nil) }
  scope :with_theater_release_it, -> { where.not(theater_air_date_it: nil) }

  def needs_update?
    last_update.nil? || last_update < 7.days.ago
  end
end
