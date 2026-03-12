class CreateTitleTvTmdb < ActiveRecord::Migration[7.1]
  def change
    create_table :title_tv_tmdb, id: false do |t|
      t.string :tconst, limit: 15, null: false, primary_key: true
      t.date :last_air_date
      t.date :next_air_date
      t.boolean :continuing, default: false
      t.datetime :last_update
      t.string :languages, limit: 100

      t.timestamps
    end

    add_index :title_tv_tmdb, :last_air_date
    add_index :title_tv_tmdb, :next_air_date
    add_index :title_tv_tmdb, :continuing
  end
end
