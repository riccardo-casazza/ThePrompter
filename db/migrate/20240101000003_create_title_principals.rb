class CreateTitlePrincipals < ActiveRecord::Migration[7.1]
  def change
    create_table :title_principals, id: false do |t|
      t.string :tconst, limit: 15, null: false
      t.integer :ordering, limit: 2, null: false
      t.string :nconst, limit: 15, null: false
      t.string :category, limit: 50, null: false

      t.timestamps
    end

    add_index :title_principals, [:tconst, :ordering], unique: true
    add_index :title_principals, :tconst
    add_index :title_principals, :nconst
    add_index :title_principals, :category
  end
end
