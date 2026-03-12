require "rails_helper"

RSpec.describe Plex::LibraryImporter do
  let(:db_path) { Rails.root.join("tmp/test_plex.db").to_s }

  before do
    PlexDatabaseHelper.create_test_database(db_path)
    PlexDatabaseHelper.populate_test_database(db_path)
  end

  after do
    File.delete(db_path) if File.exist?(db_path)
  end

  describe "#import" do
    subject(:importer) { described_class.new(db_path: db_path) }

    it "imports items from Plex database" do
      importer.import

      expect(PlexLibraryItem.count).to eq(4)
    end

    it "imports correct tconst values" do
      importer.import

      tconsts = PlexLibraryItem.pluck(:tconst)
      expect(tconsts).to contain_exactly("0000001", "0000002", "0000003", "0000004")
    end

    it "imports correct library names" do
      importer.import

      expect(PlexLibraryItem.in_library("Movies").count).to eq(2)
      expect(PlexLibraryItem.in_library("TV Shows").count).to eq(1)
      expect(PlexLibraryItem.in_library("Music").count).to eq(1)
    end

    it "imports correct metadata types" do
      importer.import

      expect(PlexLibraryItem.movies.count).to eq(2)
      expect(PlexLibraryItem.shows.count).to eq(1)
    end

    it "imports titles correctly" do
      importer.import

      matrix = PlexLibraryItem.find_by(tconst: "0000001")
      expect(matrix).to have_attributes(
        title: "The Matrix",
        original_title: nil,
        year: 1999,
        collections: "Sci-Fi Classics"
      )
    end

    it "imports original_title when present" do
      importer.import

      inception = PlexLibraryItem.find_by(tconst: "0000002")
      expect(inception.original_title).to eq("Inception Original")
    end

    it "truncates existing records before import" do
      PlexLibraryItem.create!(
        tconst: "9999999",
        library_name: "Old Library",
        metadata_type: 1,
        title: "Old Movie"
      )

      importer.import

      expect(PlexLibraryItem.find_by(tconst: "9999999")).to be_nil
      expect(PlexLibraryItem.count).to eq(4)
    end

    it "sets timestamps" do
      freeze_time do
        importer.import

        matrix = PlexLibraryItem.find_by(tconst: "0000001")
        expect(matrix.created_at).to eq(Time.current)
        expect(matrix.updated_at).to eq(Time.current)
      end
    end

    describe "import flag management" do
      it "sets import_in_progress at start" do
        allow(Setting).to receive(:import_started!)
        allow(Setting).to receive(:import_finished!)

        importer.import

        expect(Setting).to have_received(:import_started!).with("plex_library_items").ordered
        expect(Setting).to have_received(:import_finished!).with("plex_library_items").ordered
      end
    end
  end

  describe "#libraries" do
    it "returns list of library names" do
      importer = described_class.new(db_path: db_path)
      libraries = importer.libraries

      expect(libraries).to contain_exactly("Movies", "Music", "TV Shows")
    end
  end
end
