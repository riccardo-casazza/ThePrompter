require "rails_helper"

RSpec.describe TitleTvTmdb do
  describe "associations" do
    it "belongs to title_basic" do
      title_basic = create(:title_basic, tconst: "tt0000001", title_type: "tvSeries")
      tv_tmdb = TitleTvTmdb.create!(tconst: "tt0000001")

      expect(tv_tmdb.title_basic).to eq(title_basic)
    end

    it "allows records without matching title_basic" do
      tv_tmdb = TitleTvTmdb.create!(tconst: "tt9999999")
      expect(tv_tmdb.title_basic).to be_nil
    end
  end

  describe "scopes" do
    before do
      TitleTvTmdb.create!(tconst: "tt0000001", last_update: nil)
      TitleTvTmdb.create!(tconst: "tt0000002", last_update: 10.days.ago)
      TitleTvTmdb.create!(tconst: "tt0000003", last_update: 3.days.ago)
      TitleTvTmdb.create!(tconst: "tt0000004", continuing: true)
      TitleTvTmdb.create!(tconst: "tt0000005", continuing: false)
      TitleTvTmdb.create!(tconst: "tt0000006", next_air_date: 5.days.from_now)
      TitleTvTmdb.create!(tconst: "tt0000007", next_air_date: 5.days.ago)
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

    describe ".continuing" do
      it "returns records with continuing: true" do
        expect(described_class.continuing.pluck(:tconst)).to eq(["tt0000004"])
      end
    end

    describe ".ended" do
      it "returns records with continuing: false" do
        expect(described_class.ended.pluck(:tconst)).to include("tt0000005")
      end
    end

    describe ".with_upcoming_episode" do
      it "returns records with next_air_date in the future" do
        expect(described_class.with_upcoming_episode.pluck(:tconst)).to eq(["tt0000006"])
      end

      it "excludes records with next_air_date in the past" do
        expect(described_class.with_upcoming_episode.pluck(:tconst)).not_to include("tt0000007")
      end
    end
  end

  describe "#needs_update?" do
    it "returns true when last_update is nil" do
      tv = TitleTvTmdb.new(tconst: "tt0000001", last_update: nil)
      expect(tv.needs_update?).to be(true)
    end

    it "returns true when last_update is older than 7 days" do
      tv = TitleTvTmdb.new(tconst: "tt0000001", last_update: 10.days.ago)
      expect(tv.needs_update?).to be(true)
    end

    it "returns false when last_update is recent" do
      tv = TitleTvTmdb.new(tconst: "tt0000001", last_update: 3.days.ago)
      expect(tv.needs_update?).to be(false)
    end
  end
end
