require "rails_helper"

RSpec.describe PlexLibraryItem do
  describe "validations" do
    it "is valid with valid attributes" do
      item = build(:plex_library_item)
      expect(item).to be_valid
    end

    it "requires tconst" do
      item = build(:plex_library_item, tconst: nil)
      expect(item).not_to be_valid
      expect(item.errors[:tconst]).to include("can't be blank")
    end

    it "requires library_name" do
      item = build(:plex_library_item, library_name: nil)
      expect(item).not_to be_valid
      expect(item.errors[:library_name]).to include("can't be blank")
    end

    it "requires metadata_type" do
      item = build(:plex_library_item, metadata_type: nil)
      expect(item).not_to be_valid
      expect(item.errors[:metadata_type]).to include("can't be blank")
    end

    it "requires title" do
      item = build(:plex_library_item, title: nil)
      expect(item).not_to be_valid
      expect(item.errors[:title]).to include("can't be blank")
    end
  end

  describe "composite primary key" do
    it "allows same tconst in different libraries" do
      create(:plex_library_item, tconst: "tt0000001", library_name: "Movies")
      item = build(:plex_library_item, tconst: "tt0000001", library_name: "4K Movies")

      expect(item).to be_valid
    end
  end

  describe "scopes" do
    before do
      create(:plex_library_item, tconst: "0000001", library_name: "Movies", metadata_type: 1)
      create(:plex_library_item, tconst: "0000002", library_name: "Movies", metadata_type: 1)
      create(:plex_library_item, tconst: "0000003", library_name: "TV Shows", metadata_type: 2)
      create(:plex_library_item, tconst: "0000004", library_name: "Music", metadata_type: 8)
    end

    describe ".movies" do
      it "returns only movies" do
        expect(described_class.movies.count).to eq(2)
        expect(described_class.movies.pluck(:metadata_type).uniq).to eq([1])
      end
    end

    describe ".shows" do
      it "returns only TV shows" do
        expect(described_class.shows.count).to eq(1)
        expect(described_class.shows.first.tconst).to eq("0000003")
      end
    end

    describe ".in_library" do
      it "filters by library name" do
        expect(described_class.in_library("Movies").count).to eq(2)
        expect(described_class.in_library("TV Shows").count).to eq(1)
      end
    end
  end

  describe "#metadata_type_name" do
    it "returns 'movie' for metadata_type 1" do
      item = build(:plex_library_item, metadata_type: 1)
      expect(item.metadata_type_name).to eq("movie")
    end

    it "returns 'show' for metadata_type 2" do
      item = build(:plex_library_item, metadata_type: 2)
      expect(item.metadata_type_name).to eq("show")
    end

    it "returns 'artist' for metadata_type 8" do
      item = build(:plex_library_item, metadata_type: 8)
      expect(item.metadata_type_name).to eq("artist")
    end

    it "returns 'unknown' for unrecognized metadata_type" do
      item = build(:plex_library_item, metadata_type: 999)
      expect(item.metadata_type_name).to eq("unknown")
    end
  end

  describe "#display_title" do
    it "returns original_title when present" do
      item = build(:plex_library_item, title: "Title", original_title: "Original Title")
      expect(item.display_title).to eq("Original Title")
    end

    it "returns title when original_title is blank" do
      item = build(:plex_library_item, title: "Title", original_title: nil)
      expect(item.display_title).to eq("Title")
    end

    it "returns title when original_title is empty string" do
      item = build(:plex_library_item, title: "Title", original_title: "")
      expect(item.display_title).to eq("Title")
    end
  end

  describe "METADATA_TYPES" do
    it "maps known Plex metadata types" do
      expect(described_class::METADATA_TYPES[1]).to eq("movie")
      expect(described_class::METADATA_TYPES[2]).to eq("show")
      expect(described_class::METADATA_TYPES[3]).to eq("season")
      expect(described_class::METADATA_TYPES[4]).to eq("episode")
      expect(described_class::METADATA_TYPES[8]).to eq("artist")
      expect(described_class::METADATA_TYPES[9]).to eq("album")
      expect(described_class::METADATA_TYPES[10]).to eq("track")
    end
  end

  describe "associations" do
    it "belongs to title_basic" do
      title_basic = create(:title_basic, tconst: "tt0000001")
      item = create(:plex_library_item, tconst: "tt0000001")

      expect(item.title_basic).to eq(title_basic)
    end

    it "allows items without matching title_basic" do
      item = create(:plex_library_item, tconst: "tt9999999")
      expect(item.title_basic).to be_nil
    end
  end
end
