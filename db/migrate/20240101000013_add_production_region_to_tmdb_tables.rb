class AddProductionRegionToTmdbTables < ActiveRecord::Migration[7.1]
  def change
    # Movies
    add_column :title_movie_tmdb, :original_language, :string, limit: 10
    add_column :title_movie_tmdb, :production_countries, :string, limit: 100
    add_column :title_movie_tmdb, :production_region, :string, limit: 30

    add_index :title_movie_tmdb, :production_region

    # TV Shows
    add_column :title_tv_tmdb, :original_language, :string, limit: 10
    add_column :title_tv_tmdb, :production_countries, :string, limit: 100
    add_column :title_tv_tmdb, :production_region, :string, limit: 30

    add_index :title_tv_tmdb, :production_region
  end
end
