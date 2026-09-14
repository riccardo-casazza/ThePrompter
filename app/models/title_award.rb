class TitleAward < ApplicationRecord
  self.table_name = "title_awards"
  self.primary_key = "tconst"

  belongs_to :title_basic, foreign_key: :tconst, primary_key: :tconst, optional: true

  AWARD_COLUMNS = %i[
    oscar_best_picture
    golden_globe_drama
    golden_globe_musical_comedy
    golden_globe_foreign
    golden_globe_animated
    tiff_peoples_choice
    cannes_palme_dor
    cannes_un_certain_regard
    venice_golden_lion
    venice_grand_jury
  ].freeze

  scope :with_any_award, -> {
    where(AWARD_COLUMNS.map { |col| "#{col} = true" }.join(" OR "))
  }

  def awards_list
    AWARD_COLUMNS.select { |col| send(col) }
  end

  def has_any_award?
    AWARD_COLUMNS.any? { |col| send(col) }
  end
end
