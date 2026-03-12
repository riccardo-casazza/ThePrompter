require "rails_helper"

RSpec.describe TitleMovieTmdb do
  describe "associations" do
    it "belongs to title_basic" do
      title_basic = create(:title_basic, tconst: "tt0000001")
      movie_tmdb = TitleMovieTmdb.create!(tconst: "tt0000001")

      expect(movie_tmdb.title_basic).to eq(title_basic)
    end

    it "allows records without matching title_basic" do
      movie_tmdb = TitleMovieTmdb.create!(tconst: "tt9999999")
      expect(movie_tmdb.title_basic).to be_nil
    end
  end

  describe "scopes" do
    before do
      TitleMovieTmdb.create!(tconst: "tt0000001", last_update: nil)
      TitleMovieTmdb.create!(tconst: "tt0000002", last_update: 10.days.ago)
      TitleMovieTmdb.create!(tconst: "tt0000003", last_update: 3.days.ago)
      TitleMovieTmdb.create!(tconst: "tt0000004", home_air_date: Date.new(2024, 1, 1))
      TitleMovieTmdb.create!(tconst: "tt0000005", theater_air_date_fr: Date.new(2024, 2, 1))
      TitleMovieTmdb.create!(tconst: "tt0000006", theater_air_date_it: Date.new(2024, 3, 1))
    end

    describe ".needs_update" do
      it "returns records with nil last_update" do
        expect(described_class.needs_update.pluck(:tconst)).to include("tt0000001")
      end

      it "returns records with last_update older than 7 days" do
        expect(described_class.needs_update.pluck(:tconst)).to include("tt0000002")
      end

      it "excludes records with recent last_update" do
        expect(described_class.needs_update.pluck(:tconst)).not_to include("tt0000003")
      end
    end

    describe ".with_home_release" do
      it "returns records with home_air_date" do
        expect(described_class.with_home_release.pluck(:tconst)).to eq(["tt0000004"])
      end
    end

    describe ".with_theater_release_fr" do
      it "returns records with theater_air_date_fr" do
        expect(described_class.with_theater_release_fr.pluck(:tconst)).to eq(["tt0000005"])
      end
    end

    describe ".with_theater_release_it" do
      it "returns records with theater_air_date_it" do
        expect(described_class.with_theater_release_it.pluck(:tconst)).to eq(["tt0000006"])
      end
    end
  end

  describe "#needs_update?" do
    it "returns true when last_update is nil" do
      movie = TitleMovieTmdb.new(tconst: "tt0000001", last_update: nil)
      expect(movie.needs_update?).to be(true)
    end

    it "returns true when last_update is older than 7 days" do
      movie = TitleMovieTmdb.new(tconst: "tt0000001", last_update: 10.days.ago)
      expect(movie.needs_update?).to be(true)
    end

    it "returns false when last_update is recent" do
      movie = TitleMovieTmdb.new(tconst: "tt0000001", last_update: 3.days.ago)
      expect(movie.needs_update?).to be(false)
    end
  end
end
