require "rails_helper"

RSpec.describe TitleRating do
  describe "validations" do
    it "is valid with valid attributes" do
      rating = build(:title_rating)
      expect(rating).to be_valid
    end

    it "requires tconst" do
      rating = build(:title_rating, tconst: nil)
      expect(rating).not_to be_valid
      expect(rating.errors[:tconst]).to include("can't be blank")
    end

    it "requires unique tconst" do
      create(:title_rating, tconst: "tt0000001")
      duplicate = build(:title_rating, tconst: "tt0000001")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:tconst]).to include("has already been taken")
    end

    it "requires average_rating" do
      rating = build(:title_rating, average_rating: nil)
      expect(rating).not_to be_valid
      expect(rating.errors[:average_rating]).to include("can't be blank")
    end

    it "requires num_votes" do
      rating = build(:title_rating, num_votes: nil)
      expect(rating).not_to be_valid
      expect(rating.errors[:num_votes]).to include("can't be blank")
    end
  end

  describe "scopes" do
    before do
      create(:title_rating, tconst: "tt0000001", average_rating: 9.0, num_votes: 100_000)
      create(:title_rating, tconst: "tt0000002", average_rating: 6.5, num_votes: 50_000)
      create(:title_rating, tconst: "tt0000003", average_rating: 8.0, num_votes: 5_000)
      create(:title_rating, tconst: "tt0000004", average_rating: 4.0, num_votes: 500)
    end

    describe ".highly_rated" do
      it "returns ratings above threshold" do
        expect(described_class.highly_rated(7.0).count).to eq(2)
      end

      it "defaults to 7.0 threshold" do
        expect(described_class.highly_rated.count).to eq(2)
      end
    end

    describe ".popular" do
      it "returns ratings with votes above threshold" do
        expect(described_class.popular(10_000).count).to eq(2)
      end

      it "defaults to 10,000 votes threshold" do
        expect(described_class.popular.count).to eq(2)
      end
    end
  end

  describe "associations" do
    it "belongs to title_basic" do
      title = create(:title_basic, tconst: "tt1234567")
      rating = create(:title_rating, tconst: "tt1234567")

      expect(rating.title_basic).to eq(title)
    end
  end
end
