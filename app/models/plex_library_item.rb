class PlexLibraryItem < ApplicationRecord
  self.table_name = "plex_library_items"
  self.primary_key = [:tconst, :library_name]

  # Known Plex metadata types
  METADATA_TYPES = {
    1 => "movie",
    2 => "show",
    3 => "season",
    4 => "episode",
    8 => "artist",
    9 => "album",
    10 => "track"
  }.freeze

  belongs_to :title_basic, foreign_key: :tconst, primary_key: :tconst, optional: true

  validates :tconst, presence: true
  validates :library_name, presence: true
  validates :metadata_type, presence: true
  validates :title, presence: true

  scope :movies, -> { where(metadata_type: 1) }
  scope :shows, -> { where(metadata_type: 2) }
  scope :in_library, ->(name) { where(library_name: name) }

  def metadata_type_name
    METADATA_TYPES[metadata_type] || "unknown"
  end

  def display_title
    original_title.presence || title
  end
end
