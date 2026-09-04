class AddCompositeIndexesForTitleSearch < ActiveRecord::Migration[7.1]
  def change
    # Primary optimization: Composite index on title_basics for filtering by type and year
    # This eliminates the bottleneck where PostgreSQL scans by tconst then filters by type/year
    # Expected impact: Reduce query time from ~1.95s to <200ms for typical searches
    add_index :title_basics, [:title_type, :start_year],
              name: "index_title_basics_on_type_and_year"

    # Additional optimization: Include tconst in the index to make it a covering index
    # This allows index-only scans without touching the table heap
    # Note: PostgreSQL automatically includes the primary key in all indexes, so this might be redundant
    # but explicitly including tconst can help the query planner choose better plans
    add_index :title_basics, [:title_type, :start_year, :tconst],
              name: "index_title_basics_on_type_year_tconst"
  end
end
