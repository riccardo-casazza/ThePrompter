class CreateTitleMovieTmdb < ActiveRecord::Migration[7.1]
  def change
    create_table :title_movie_tmdb, id: false do |t|
      t.string :tconst, limit: 15, null: false, primary_key: true
      t.date :home_air_date
      t.date :theater_air_date_fr
      t.date :theater_air_date_it
      t.datetime :last_update
      t.string :languages, limit: 100

      t.timestamps
    end

    add_index :title_movie_tmdb, :home_air_date
    add_index :title_movie_tmdb, :theater_air_date_fr
    add_index :title_movie_tmdb, :theater_air_date_it
  end
end
