class CreateTitleAwards < ActiveRecord::Migration[7.1]
  def change
    create_table :title_awards, id: false do |t|
      t.string :tconst, null: false, primary_key: true
      t.boolean :oscar_best_picture, default: false, null: false
      t.boolean :golden_globe_drama, default: false, null: false
      t.boolean :golden_globe_musical_comedy, default: false, null: false
      t.boolean :golden_globe_foreign, default: false, null: false
      t.boolean :golden_globe_animated, default: false, null: false
      t.boolean :tiff_peoples_choice, default: false, null: false
      t.boolean :cannes_palme_dor, default: false, null: false
      t.boolean :cannes_un_certain_regard, default: false, null: false
      t.boolean :venice_golden_lion, default: false, null: false
      t.boolean :venice_grand_jury, default: false, null: false
      t.timestamps
    end

    add_index :title_awards, :oscar_best_picture, where: "oscar_best_picture = true"
    add_index :title_awards, :cannes_palme_dor, where: "cannes_palme_dor = true"
    add_index :title_awards, :venice_golden_lion, where: "venice_golden_lion = true"
  end
end
