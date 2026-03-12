module Tmdb
  class Consolidator
    MOVIE_TYPES = %w[movie tvMovie].freeze
    TV_TYPES = %w[tvSeries tvMiniSeries].freeze
    BATCH_SIZE = 10_000

    def consolidate
      consolidate_movies
      consolidate_tv_shows

      {
        movies: {
          added: @movies_added,
          removed: @movies_removed
        },
        tv_shows: {
          added: @tv_added,
          removed: @tv_removed
        }
      }
    end

    def consolidate_movies
      @movies_added = add_new_movies
      @movies_removed = remove_orphaned_movies
    end

    def consolidate_tv_shows
      @tv_added = add_new_tv_shows
      @tv_removed = remove_orphaned_tv_shows
    end

    private

    def add_new_movies
      count = 0
      now = Time.current

      movie_tconsts_to_add.each_slice(BATCH_SIZE) do |batch|
        records = batch.map do |tconst|
          {
            tconst: tconst,
            created_at: now,
            updated_at: now
          }
        end

        TitleMovieTmdb.upsert_all(records, unique_by: :tconst) if records.any?
        count += records.size
      end

      count
    end

    def add_new_tv_shows
      count = 0
      now = Time.current

      tv_tconsts_to_add.each_slice(BATCH_SIZE) do |batch|
        records = batch.map do |tconst|
          {
            tconst: tconst,
            continuing: false,
            created_at: now,
            updated_at: now
          }
        end

        TitleTvTmdb.upsert_all(records, unique_by: :tconst) if records.any?
        count += records.size
      end

      count
    end

    def remove_orphaned_movies
      orphaned = TitleMovieTmdb
        .where.not(tconst: TitleBasic.select(:tconst))
        .pluck(:tconst)

      TitleMovieTmdb.where(tconst: orphaned).delete_all if orphaned.any?

      orphaned.size
    end

    def remove_orphaned_tv_shows
      orphaned = TitleTvTmdb
        .where.not(tconst: TitleBasic.select(:tconst))
        .pluck(:tconst)

      TitleTvTmdb.where(tconst: orphaned).delete_all if orphaned.any?

      orphaned.size
    end

    def movie_tconsts_to_add
      TitleBasic
        .where(title_type: MOVIE_TYPES)
        .where("genres IS NULL OR genres NOT LIKE ?", "%Short%")
        .where.not(tconst: TitleMovieTmdb.select(:tconst))
        .pluck(:tconst)
    end

    def tv_tconsts_to_add
      TitleBasic
        .where(title_type: TV_TYPES)
        .where("genres IS NULL OR genres NOT LIKE ?", "%Short%")
        .where.not(tconst: TitleTvTmdb.select(:tconst))
        .pluck(:tconst)
    end
  end
end
