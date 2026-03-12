class CreateTitleRatings < ActiveRecord::Migration[7.1]
  def change
    create_table :title_ratings, id: false do |t|
      t.string :tconst, limit: 15, null: false, primary_key: true
      t.decimal :average_rating, precision: 3, scale: 1, null: false
      t.integer :num_votes, null: false

      t.timestamps
    end

    add_index :title_ratings, :average_rating
    add_index :title_ratings, :num_votes
  end
end
