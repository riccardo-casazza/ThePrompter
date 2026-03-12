require "rails_helper"

RSpec.describe MyRating do
  describe "validations" do
    it "is valid with valid attributes" do
      rating = build(:my_rating)
      expect(rating).to be_valid
    end

    it "requires tconst" do
      rating = build(:my_rating, tconst: nil)
      expect(rating).not_to be_valid
      expect(rating.errors[:tconst]).to include("can't be blank")
    end

    it "requires unique tconst" do
      create(:my_rating, tconst: "tt0000001")
      duplicate = build(:my_rating, tconst: "tt0000001")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:tconst]).to include("has already been taken")
    end

    it "requires rating" do
      rating = build(:my_rating, rating: nil)
      expect(rating).not_to be_valid
      expect(rating.errors[:rating]).to include("can't be blank")
    end

    it "validates rating is between 1 and 10" do
      expect(build(:my_rating, rating: 0)).not_to be_valid
      expect(build(:my_rating, rating: 11)).not_to be_valid
      expect(build(:my_rating, rating: 1)).to be_valid
      expect(build(:my_rating, rating: 10)).to be_valid
    end

    it "validates rating is an integer" do
      rating = build(:my_rating, rating: 7.5)
      expect(rating).not_to be_valid
      expect(rating.errors[:rating]).to include("must be an integer")
    end
  end

  describe "scopes" do
    before do
      create(:my_rating, tconst: "tt0000001", rating: 9)
      create(:my_rating, tconst: "tt0000002", rating: 8)
      create(:my_rating, tconst: "tt0000003", rating: 5)
      create(:my_rating, tconst: "tt0000004", rating: 3)
      create(:my_rating, tconst: "tt0000005", rating: 4)
    end

    describe ".highly_rated" do
      it "returns ratings >= 8" do
        expect(described_class.highly_rated.count).to eq(2)
        expect(described_class.highly_rated.pluck(:rating)).to all(be >= 8)
      end
    end

    describe ".low_rated" do
      it "returns ratings <= 4" do
        expect(described_class.low_rated.count).to eq(2)
        expect(described_class.low_rated.pluck(:rating)).to all(be <= 4)
      end
    end
  end

  describe "associations" do
    it "belongs to title_basic" do
      title_basic = create(:title_basic, tconst: "tt0000001")
      rating = create(:my_rating, tconst: "tt0000001")

      expect(rating.title_basic).to eq(title_basic)
    end

    it "allows ratings without matching title_basic" do
      rating = create(:my_rating, tconst: "tt9999999")
      expect(rating.title_basic).to be_nil
    end
  end

  describe "#imdb_url" do
    it "returns the correct IMDb URL" do
      rating = build(:my_rating, tconst: "tt1234567")
      expect(rating.imdb_url).to eq("https://www.imdb.com/title/tt1234567")
    end
  end
end
