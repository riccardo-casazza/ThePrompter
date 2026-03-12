class MyRating < ApplicationRecord
  self.table_name = "my_ratings"
  self.primary_key = "tconst"

  validates :tconst, presence: true, uniqueness: true
  validates :rating, presence: true, numericality: { only_integer: true, in: 1..10 }

  belongs_to :title_basic, foreign_key: :tconst, primary_key: :tconst, optional: true

  scope :highly_rated, -> { where("rating >= ?", 8) }
  scope :low_rated, -> { where("rating <= ?", 4) }

  def imdb_url
    "https://www.imdb.com/title/#{tconst}"
  end
end
