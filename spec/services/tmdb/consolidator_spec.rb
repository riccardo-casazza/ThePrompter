require "rails_helper"

RSpec.describe Tmdb::Consolidator do
  describe "#consolidate" do
    subject(:result) { described_class.new.consolidate }

    context "with movies" do
      before do
        # Movies that should be added to TMDB
        create(:title_basic, tconst: "tt0000001", title_type: "movie", genres: "Action")
        create(:title_basic, tconst: "tt0000002", title_type: "tvMovie", genres: "Drama")
        create(:title_basic, tconst: "tt0000003", title_type: "movie", genres: nil)

        # Movie already in TMDB
        create(:title_basic, tconst: "tt0000004", title_type: "movie", genres: "Comedy")
        TitleMovieTmdb.create!(tconst: "tt0000004")

        # Movie with Short genre should be excluded
        create(:title_basic, tconst: "tt0000005", title_type: "movie", genres: "Short,Comedy")

        # Orphaned TMDB entry (no matching title_basic)
        TitleMovieTmdb.create!(tconst: "tt9999999")
      end

      it "adds new movies to TMDB" do
        result
        expect(TitleMovieTmdb.pluck(:tconst)).to include("tt0000001", "tt0000002", "tt0000003")
      end

      it "excludes movies with Short genre" do
        result
        expect(TitleMovieTmdb.pluck(:tconst)).not_to include("tt0000005")
      end

      it "removes orphaned TMDB entries" do
        result
        expect(TitleMovieTmdb.find_by(tconst: "tt9999999")).to be_nil
      end

      it "returns correct movie counts" do
        expect(result[:movies][:added]).to eq(3)
        expect(result[:movies][:removed]).to eq(1)
      end

      it "does not duplicate existing entries" do
        result
        expect(TitleMovieTmdb.where(tconst: "tt0000004").count).to eq(1)
      end
    end

    context "with TV shows" do
      before do
        # TV shows that should be added to TMDB
        create(:title_basic, tconst: "tt0000001", title_type: "tvSeries", genres: "Drama")
        create(:title_basic, tconst: "tt0000002", title_type: "tvMiniSeries", genres: "Crime")
        create(:title_basic, tconst: "tt0000003", title_type: "tvSeries", genres: nil)

        # TV show already in TMDB
        create(:title_basic, tconst: "tt0000004", title_type: "tvSeries", genres: "Comedy")
        TitleTvTmdb.create!(tconst: "tt0000004")

        # TV show with Short genre should be excluded
        create(:title_basic, tconst: "tt0000005", title_type: "tvSeries", genres: "Short,Documentary")

        # Orphaned TMDB entry
        TitleTvTmdb.create!(tconst: "tt9999999")
      end

      it "adds new TV shows to TMDB" do
        result
        expect(TitleTvTmdb.pluck(:tconst)).to include("tt0000001", "tt0000002", "tt0000003")
      end

      it "excludes TV shows with Short genre" do
        result
        expect(TitleTvTmdb.pluck(:tconst)).not_to include("tt0000005")
      end

      it "removes orphaned TMDB entries" do
        result
        expect(TitleTvTmdb.find_by(tconst: "tt9999999")).to be_nil
      end

      it "returns correct TV show counts" do
        expect(result[:tv_shows][:added]).to eq(3)
        expect(result[:tv_shows][:removed]).to eq(1)
      end

      it "sets continuing to false by default" do
        result
        expect(TitleTvTmdb.find_by(tconst: "tt0000001").continuing).to be(false)
      end
    end

    context "with no changes needed" do
      before do
        create(:title_basic, tconst: "tt0000001", title_type: "movie")
        TitleMovieTmdb.create!(tconst: "tt0000001")

        create(:title_basic, tconst: "tt0000002", title_type: "tvSeries")
        TitleTvTmdb.create!(tconst: "tt0000002")
      end

      it "returns zero counts" do
        expect(result[:movies][:added]).to eq(0)
        expect(result[:movies][:removed]).to eq(0)
        expect(result[:tv_shows][:added]).to eq(0)
        expect(result[:tv_shows][:removed]).to eq(0)
      end
    end

    context "with excluded title types" do
      before do
        create(:title_basic, tconst: "tt0000001", title_type: "short")
        create(:title_basic, tconst: "tt0000002", title_type: "tvEpisode")
        create(:title_basic, tconst: "tt0000003", title_type: "videoGame")
      end

      it "does not add non-movie/TV types" do
        result
        expect(TitleMovieTmdb.count).to eq(0)
        expect(TitleTvTmdb.count).to eq(0)
      end
    end
  end

  describe "#consolidate_movies" do
    it "only processes movies" do
      create(:title_basic, tconst: "tt0000001", title_type: "movie")
      create(:title_basic, tconst: "tt0000002", title_type: "tvSeries")

      described_class.new.consolidate_movies

      expect(TitleMovieTmdb.count).to eq(1)
      expect(TitleTvTmdb.count).to eq(0)
    end
  end

  describe "#consolidate_tv_shows" do
    it "only processes TV shows" do
      create(:title_basic, tconst: "tt0000001", title_type: "movie")
      create(:title_basic, tconst: "tt0000002", title_type: "tvSeries")

      described_class.new.consolidate_tv_shows

      expect(TitleMovieTmdb.count).to eq(0)
      expect(TitleTvTmdb.count).to eq(1)
    end
  end
end
