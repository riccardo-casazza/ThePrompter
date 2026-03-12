require "rails_helper"

RSpec.describe TitleBasic do
  describe "validations" do
    it "is valid with valid attributes" do
      title = build(:title_basic)
      expect(title).to be_valid
    end

    it "requires tconst" do
      title = build(:title_basic, tconst: nil)
      expect(title).not_to be_valid
      expect(title.errors[:tconst]).to include("can't be blank")
    end

    it "requires unique tconst" do
      create(:title_basic, tconst: "tt0000001")
      duplicate = build(:title_basic, tconst: "tt0000001")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:tconst]).to include("has already been taken")
    end

    it "requires title_type" do
      title = build(:title_basic, title_type: nil)
      expect(title).not_to be_valid
      expect(title.errors[:title_type]).to include("can't be blank")
    end

    it "requires original_title" do
      title = build(:title_basic, original_title: nil)
      expect(title).not_to be_valid
      expect(title.errors[:original_title]).to include("can't be blank")
    end
  end

  describe "scopes" do
    before do
      create(:title_basic, tconst: "tt0000001", title_type: "movie")
      create(:title_basic, tconst: "tt0000002", title_type: "tvSeries")
      create(:title_basic, tconst: "tt0000003", title_type: "tvMiniSeries")
      create(:title_basic, tconst: "tt0000004", title_type: "movie")
    end

    describe ".movies" do
      it "returns only movies" do
        expect(described_class.movies.count).to eq(2)
        expect(described_class.movies.pluck(:title_type).uniq).to eq(["movie"])
      end
    end

    describe ".tv_series" do
      it "returns only TV series" do
        expect(described_class.tv_series.count).to eq(1)
        expect(described_class.tv_series.first.tconst).to eq("tt0000002")
      end
    end

    describe ".tv_mini_series" do
      it "returns only TV mini series" do
        expect(described_class.tv_mini_series.count).to eq(1)
        expect(described_class.tv_mini_series.first.tconst).to eq("tt0000003")
      end
    end
  end

  describe "#imdb_url" do
    it "returns the correct IMDb URL" do
      title = build(:title_basic, tconst: "tt1234567")
      expect(title.imdb_url).to eq("https://www.imdb.com/title/tt1234567")
    end
  end

  describe "EXCLUDED_TITLE_TYPES" do
    it "includes all types that should be filtered during import" do
      expected = %w[tvEpisode tvSpecial video videoGame tvPilot]
      expect(described_class::EXCLUDED_TITLE_TYPES).to match_array(expected)
    end

    it "does not exclude shorts" do
      expect(described_class::EXCLUDED_TITLE_TYPES).not_to include("short", "tvShort")
    end
  end
end
