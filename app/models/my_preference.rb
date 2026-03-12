class MyPreference < ApplicationRecord
  self.table_name = "my_preferences"

  CATEGORIES = %w[actor writer director composer].freeze

  validates :nconst, presence: true
  validates :primary_name, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :nconst, uniqueness: { scope: :category }

  scope :actors, -> { where(category: "actor") }
  scope :writers, -> { where(category: "writer") }
  scope :directors, -> { where(category: "director") }
  scope :composers, -> { where(category: "composer") }

  def imdb_url
    "https://www.imdb.com/name/#{nconst}"
  end
end
