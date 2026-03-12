# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2024_01_01_000011) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "blacklist", primary_key: "tconst", id: { type: :string, limit: 15 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "my_preferences", id: false, force: :cascade do |t|
    t.string "nconst", limit: 15, null: false
    t.string "primary_name", limit: 255, null: false
    t.string "category", limit: 50, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_my_preferences_on_category"
    t.index ["nconst", "category"], name: "index_my_preferences_on_nconst_and_category", unique: true
  end

  create_table "my_ratings", primary_key: "tconst", id: { type: :string, limit: 15 }, force: :cascade do |t|
    t.integer "rating", limit: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["rating"], name: "index_my_ratings_on_rating"
  end

  create_table "plex_library_items", id: false, force: :cascade do |t|
    t.string "tconst", limit: 15, null: false
    t.string "library_name", limit: 100, null: false
    t.integer "metadata_type", null: false
    t.string "title", limit: 512, null: false
    t.string "original_title", limit: 512
    t.integer "year", limit: 2
    t.string "collections", limit: 1024
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false
    t.index ["library_name"], name: "index_plex_library_items_on_library_name"
    t.index ["metadata_type"], name: "index_plex_library_items_on_metadata_type"
    t.index ["tconst", "library_name"], name: "index_plex_library_items_on_tconst_and_library_name", unique: true
    t.index ["tconst"], name: "index_plex_library_items_on_tconst"
    t.index ["year"], name: "index_plex_library_items_on_year"
  end

  create_table "settings", force: :cascade do |t|
    t.string "key", null: false
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "title_basics", primary_key: "tconst", id: { type: :string, limit: 15 }, force: :cascade do |t|
    t.string "title_type", limit: 255, null: false
    t.string "original_title", limit: 512, null: false
    t.integer "start_year", limit: 2
    t.integer "runtime_minutes"
    t.string "genres", limit: 255
    t.string "url", limit: 50
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false
    t.index ["genres"], name: "index_title_basics_on_genres"
    t.index ["start_year"], name: "index_title_basics_on_start_year"
    t.index ["title_type"], name: "index_title_basics_on_title_type"
  end

  create_table "title_movie_tmdb", primary_key: "tconst", id: { type: :string, limit: 15 }, force: :cascade do |t|
    t.date "home_air_date"
    t.date "theater_air_date_fr"
    t.date "theater_air_date_it"
    t.datetime "last_update"
    t.string "languages", limit: 100
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "tmdb_not_found", default: false, null: false
    t.index ["home_air_date"], name: "index_title_movie_tmdb_on_home_air_date"
    t.index ["theater_air_date_fr"], name: "index_title_movie_tmdb_on_theater_air_date_fr"
    t.index ["theater_air_date_it"], name: "index_title_movie_tmdb_on_theater_air_date_it"
    t.index ["tmdb_not_found"], name: "index_title_movie_tmdb_on_tmdb_not_found"
  end

  create_table "title_principals", id: false, force: :cascade do |t|
    t.string "tconst", limit: 15, null: false
    t.integer "ordering", limit: 2, null: false
    t.string "nconst", limit: 15, null: false
    t.string "category", limit: 50, null: false
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false
    t.index ["category"], name: "index_title_principals_on_category"
    t.index ["nconst"], name: "index_title_principals_on_nconst"
    t.index ["tconst", "ordering"], name: "index_title_principals_on_tconst_and_ordering", unique: true
    t.index ["tconst"], name: "index_title_principals_on_tconst"
  end

  create_table "title_ratings", primary_key: "tconst", id: { type: :string, limit: 15 }, force: :cascade do |t|
    t.decimal "average_rating", precision: 3, scale: 1, null: false
    t.integer "num_votes", null: false
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false
    t.datetime "updated_at", precision: nil, default: -> { "now()" }, null: false
    t.index ["average_rating"], name: "index_title_ratings_on_average_rating"
    t.index ["num_votes"], name: "index_title_ratings_on_num_votes"
  end

  create_table "title_tv_tmdb", primary_key: "tconst", id: { type: :string, limit: 15 }, force: :cascade do |t|
    t.date "last_air_date"
    t.date "next_air_date"
    t.boolean "continuing", default: false
    t.datetime "last_update"
    t.string "languages", limit: 100
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "tmdb_not_found", default: false, null: false
    t.index ["continuing"], name: "index_title_tv_tmdb_on_continuing"
    t.index ["last_air_date"], name: "index_title_tv_tmdb_on_last_air_date"
    t.index ["next_air_date"], name: "index_title_tv_tmdb_on_next_air_date"
    t.index ["tmdb_not_found"], name: "index_title_tv_tmdb_on_tmdb_not_found"
  end

end
