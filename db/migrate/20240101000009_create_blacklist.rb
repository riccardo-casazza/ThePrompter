class CreateBlacklist < ActiveRecord::Migration[7.1]
  def change
    create_table :blacklist, primary_key: :tconst, id: { type: :string, limit: 15 } do |t|
      t.timestamps
    end
  end
end
