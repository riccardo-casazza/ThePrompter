class CreateMyRatings < ActiveRecord::Migration[7.1]
  def change
    create_table :my_ratings, primary_key: :tconst, id: { type: :string, limit: 15 } do |t|
      t.integer :rating, limit: 2, null: false

      t.timestamps
    end

    add_index :my_ratings, :rating
  end
end
