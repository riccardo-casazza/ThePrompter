class TitleTvTmdb < ApplicationRecord
  self.table_name = "title_tv_tmdb"
  self.primary_key = "tconst"

  belongs_to :title_basic, foreign_key: :tconst, primary_key: :tconst, optional: true

  # Retry found shows every 7 days, not found shows every 30 days
  scope :needs_update, -> {
    where(last_update: nil)
      .or(where(tmdb_not_found: false).where("last_update < ?", 7.days.ago))
      .or(where(tmdb_not_found: true).where("last_update < ?", 30.days.ago))
  }
  scope :continuing, -> { where(continuing: true) }
  scope :ended, -> { where(continuing: false) }
  scope :with_upcoming_episode, -> { where("next_air_date >= ?", Date.current) }

  def needs_update?
    last_update.nil? || last_update < 7.days.ago
  end
end
