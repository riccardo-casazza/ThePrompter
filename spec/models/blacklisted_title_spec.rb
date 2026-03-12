require "rails_helper"

RSpec.describe BlacklistedTitle do
  describe "validations" do
    it "is valid with valid attributes" do
      title = build(:blacklisted_title)
      expect(title).to be_valid
    end

    it "requires tconst" do
      title = build(:blacklisted_title, tconst: nil)
      expect(title).not_to be_valid
      expect(title.errors[:tconst]).to include("can't be blank")
    end

    it "requires unique tconst" do
      create(:blacklisted_title, tconst: "tt0000001")
      duplicate = build(:blacklisted_title, tconst: "tt0000001")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:tconst]).to include("has already been taken")
    end
  end

  describe "associations" do
    it "belongs to title_basic" do
      title_basic = create(:title_basic, tconst: "tt0000001")
      blacklisted = create(:blacklisted_title, tconst: "tt0000001")

      expect(blacklisted.title_basic).to eq(title_basic)
    end

    it "allows blacklisted titles without matching title_basic" do
      blacklisted = create(:blacklisted_title, tconst: "tt9999999")
      expect(blacklisted.title_basic).to be_nil
    end
  end

  describe "#imdb_url" do
    it "returns the correct IMDb URL" do
      title = build(:blacklisted_title, tconst: "tt1234567")
      expect(title.imdb_url).to eq("https://www.imdb.com/title/tt1234567")
    end
  end
end
