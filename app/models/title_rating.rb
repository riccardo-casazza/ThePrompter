class TitleRating < ApplicationRecord
  self.table_name = "title_ratings"
  self.primary_key = "tconst"

  belongs_to :title_basic, foreign_key: :tconst, primary_key: :tconst, optional: true

  validates :tconst, presence: true, uniqueness: true
  validates :average_rating, presence: true
  validates :num_votes, presence: true

  scope :highly_rated, ->(min_rating = 7.0) { where("average_rating >= ?", min_rating) }
  scope :popular, ->(min_votes = 10_000) { where("num_votes >= ?", min_votes) }
end
