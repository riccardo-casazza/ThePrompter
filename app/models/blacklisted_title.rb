class BlacklistedTitle < ApplicationRecord
  self.table_name = "blacklist"
  self.primary_key = "tconst"

  validates :tconst, presence: true, uniqueness: true

  belongs_to :title_basic, foreign_key: :tconst, primary_key: :tconst, optional: true

  def imdb_url
    "https://www.imdb.com/title/#{tconst}"
  end
end
