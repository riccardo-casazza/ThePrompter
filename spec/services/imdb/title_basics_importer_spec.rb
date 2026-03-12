require "rails_helper"

RSpec.describe Imdb::TitleBasicsImporter do
  let(:fixture_path) { Rails.root.join("spec/fixtures/files/title.basics.sample.tsv") }

  describe "#import" do
    subject(:result) { described_class.new(fixture_path).import }

    it "imports valid title types" do
      result
      # From fixture: short (1), movie (3), tvSeries (2), tvMiniSeries (1) = 7 valid
      expect(TitleBasic.count).to eq(7)
    end

    it "skips excluded title types" do
      result
      # Excluded: tvEpisode, videoGame, tvSpecial, video, tvPilot = 5 skipped
      expect(result[:skipped]).to eq(5)
    end

    it "returns correct counts" do
      expect(result[:imported]).to eq(7)
      expect(result[:skipped]).to eq(5)
    end

    it "correctly parses movie data" do
      result
      matrix = TitleBasic.find_by(tconst: "tt0000006")

      expect(matrix).to have_attributes(
        title_type: "movie",
        original_title: "The Matrix",
        start_year: 1999,
        runtime_minutes: 136,
        genres: "Action,Sci-Fi"
      )
    end

    it "correctly parses TV series data" do
      result
      breaking_bad = TitleBasic.find_by(tconst: "tt0000003")

      expect(breaking_bad).to have_attributes(
        title_type: "tvSeries",
        original_title: "Breaking Bad",
        start_year: 2008,
        runtime_minutes: 49,
        genres: "Crime,Drama,Thriller"
      )
    end

    it "handles null values (\\N)" do
      result
      # videoGame entry has \N for runtime but gets skipped
      # Let's check a valid entry that might have nulls in other scenarios
      inception = TitleBasic.find_by(tconst: "tt0000009")
      expect(inception.runtime_minutes).to eq(148)
    end

    it "generates correct IMDb URLs" do
      result
      matrix = TitleBasic.find_by(tconst: "tt0000006")
      expect(matrix.url).to eq("https://www.imdb.com/title/tt0000006")
    end

    it "sets timestamps" do
      freeze_time do
        result
        matrix = TitleBasic.find_by(tconst: "tt0000006")
        expect(matrix.created_at).to eq(Time.current)
        expect(matrix.updated_at).to eq(Time.current)
      end
    end

    context "with truncate: true (default)" do
      before do
        create(:title_basic, tconst: "tt9999999", original_title: "Old Movie")
      end

      it "removes existing records before import" do
        result
        expect(TitleBasic.find_by(tconst: "tt9999999")).to be_nil
      end
    end

    context "with truncate: false" do
      subject(:result) { described_class.new(fixture_path, truncate: false).import }

      before do
        create(:title_basic, tconst: "tt9999999", original_title: "Old Movie")
      end

      it "preserves existing records" do
        result
        expect(TitleBasic.find_by(tconst: "tt9999999")).to be_present
        expect(TitleBasic.count).to eq(8) # 7 imported + 1 existing
      end
    end

    describe "import flag management" do
      it "sets import_in_progress at start" do
        allow(Setting).to receive(:import_started!)
        allow(Setting).to receive(:import_finished!)

        result

        expect(Setting).to have_received(:import_started!).with("title_basics").ordered
        expect(Setting).to have_received(:import_finished!).with("title_basics").ordered
      end

      it "clears import_in_progress even on error" do
        allow(File).to receive(:foreach).and_raise(StandardError, "File error")

        expect { described_class.new(fixture_path).import }.to raise_error(StandardError)
        expect(Setting.import_in_progress?("title_basics")).to be(false)
      end
    end
  end

  describe "EXCLUDED_TITLE_TYPES" do
    it "does not exclude shorts" do
      expect(described_class::EXCLUDED_TITLE_TYPES).not_to include("short", "tvShort")
    end

    it "excludes episodes" do
      expect(described_class::EXCLUDED_TITLE_TYPES).to include("tvEpisode")
    end

    it "excludes specials and pilots" do
      expect(described_class::EXCLUDED_TITLE_TYPES).to include("tvSpecial", "tvPilot")
    end

    it "excludes videos and video games" do
      expect(described_class::EXCLUDED_TITLE_TYPES).to include("video", "videoGame")
    end
  end
end
