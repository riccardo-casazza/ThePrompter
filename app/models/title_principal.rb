class TitlePrincipal < ApplicationRecord
  self.table_name = "title_principals"
  self.primary_key = [:tconst, :ordering]

  INCLUDED_CATEGORIES = %w[
    actor
    actress
    director
    writer
    composer
  ].freeze

  belongs_to :title_basic, foreign_key: :tconst, primary_key: :tconst, optional: true

  validates :tconst, presence: true
  validates :ordering, presence: true
  validates :nconst, presence: true
  validates :category, presence: true

  scope :actors, -> { where(category: "actor") }
  scope :directors, -> { where(category: "director") }
  scope :writers, -> { where(category: "writer") }
  scope :composers, -> { where(category: "composer") }
end
