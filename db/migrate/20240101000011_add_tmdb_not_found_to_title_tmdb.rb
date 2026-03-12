class AddTmdbNotFoundToTitleTmdb < ActiveRecord::Migration[7.1]
  def change
    add_column :title_movie_tmdb, :tmdb_not_found, :boolean, default: false, null: false
    add_column :title_tv_tmdb, :tmdb_not_found, :boolean, default: false, null: false

    add_index :title_movie_tmdb, :tmdb_not_found
    add_index :title_tv_tmdb, :tmdb_not_found
  end
end
