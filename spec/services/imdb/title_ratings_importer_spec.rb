require "rails_helper"

RSpec.describe Imdb::TitleRatingsImporter do
  let(:fixture_path) { Rails.root.join("spec/fixtures/files/title.ratings.sample.tsv") }

  # Create title_basics entries that match some ratings in fixture
  before do
    # These match ratings in the fixture (will be imported)
    create(:title_basic, tconst: "tt0000001")
    create(:title_basic, tconst: "tt0000003")
    create(:title_basic, tconst: "tt0000006")
    create(:title_basic, tconst: "tt0000009")
    create(:title_basic, tconst: "tt0000012")
    # tt9999999 is in ratings fixture but NOT in title_basics - should be skipped
  end

  describe "#import" do
    subject(:result) { described_class.new(fixture_path).import }

    it "imports only ratings for titles that exist in title_basics" do
      result
      # Only 5 titles exist in title_basics
      expect(TitleRating.count).to eq(5)
    end

    it "skips ratings for titles not in title_basics" do
      result
      # 13 total ratings - 5 valid = 8 skipped
      expect(result[:skipped]).to eq(8)
    end

    it "returns correct counts" do
      expect(result[:imported]).to eq(5)
      expect(result[:skipped]).to eq(8)
    end

    it "correctly parses rating data" do
      result
      rating = TitleRating.find_by(tconst: "tt0000006")

      expect(rating).to have_attributes(
        tconst: "tt0000006",
        average_rating: 8.7,
        num_votes: 2_000_000
      )
    end

    it "correctly parses high-vote titles" do
      result
      inception = TitleRating.find_by(tconst: "tt0000009")

      expect(inception).to have_attributes(
        average_rating: 8.8,
        num_votes: 2_500_000
      )
    end

    it "sets timestamps" do
      freeze_time do
        result
        rating = TitleRating.first
        expect(rating.created_at).to eq(Time.current)
        expect(rating.updated_at).to eq(Time.current)
      end
    end

    context "with truncate: true (default)" do
      before do
        create(:title_rating, tconst: "tt0000001", average_rating: 1.0, num_votes: 1)
      end

      it "removes existing records before import" do
        result
        rating = TitleRating.find_by(tconst: "tt0000001")
        # Should have the new data from fixture, not the old data
        expect(rating.average_rating).to eq(5.7)
        expect(rating.num_votes).to eq(1500)
      end
    end

    context "with truncate: false" do
      subject(:result) { described_class.new(fixture_path, truncate: false).import }

      before do
        # Create a rating for a title that's NOT in the fixture
        create(:title_basic, tconst: "tt8888888")
        create(:title_rating, tconst: "tt8888888", average_rating: 5.0, num_votes: 100)
      end

      it "preserves existing records" do
        result
        expect(TitleRating.find_by(tconst: "tt8888888")).to be_present
        expect(TitleRating.count).to eq(6) # 5 imported + 1 existing
      end
    end

    describe "import flag management" do
      it "sets import_in_progress at start" do
        allow(Setting).to receive(:import_started!)
        allow(Setting).to receive(:import_finished!)

        result

        expect(Setting).to have_received(:import_started!).with("title_ratings").ordered
        expect(Setting).to have_received(:import_finished!).with("title_ratings").ordered
      end

      it "clears import_in_progress even on error" do
        allow(File).to receive(:foreach).and_raise(StandardError, "File error")

        expect { described_class.new(fixture_path).import }.to raise_error(StandardError)
        expect(Setting.import_in_progress?("title_ratings")).to be(false)
      end
    end
  end

  describe "filtering behavior" do
    it "only imports ratings for existing titles" do
      result = described_class.new(fixture_path).import

      imported_tconsts = TitleRating.pluck(:tconst)
      expected_tconsts = %w[tt0000001 tt0000003 tt0000006 tt0000009 tt0000012]

      expect(imported_tconsts).to match_array(expected_tconsts)
    end

    it "does not import tt9999999 which is not in title_basics" do
      described_class.new(fixture_path).import

      expect(TitleRating.find_by(tconst: "tt9999999")).to be_nil
    end
  end
end
