class TitleBasic < ApplicationRecord
  self.table_name = "title_basics"
  self.primary_key = "tconst"

  EXCLUDED_TITLE_TYPES = %w[
    tvEpisode
    tvSpecial
    video
    videoGame
    tvPilot
  ].freeze

  IMDB_URL_BASE = "https://www.imdb.com/title/".freeze

  validates :tconst, presence: true, uniqueness: true
  validates :title_type, presence: true
  validates :original_title, presence: true

  scope :movies, -> { where(title_type: "movie") }
  scope :tv_series, -> { where(title_type: "tvSeries") }
  scope :tv_mini_series, -> { where(title_type: "tvMiniSeries") }

  def imdb_url
    "#{IMDB_URL_BASE}#{tconst}"
  end
end
