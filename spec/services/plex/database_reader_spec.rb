require "rails_helper"

RSpec.describe Plex::DatabaseReader do
  let(:db_path) { Rails.root.join("tmp/test_plex.db").to_s }

  before do
    PlexDatabaseHelper.create_test_database(db_path)
    PlexDatabaseHelper.populate_test_database(db_path)
  end

  after do
    File.delete(db_path) if File.exist?(db_path)
  end

  describe "#each_item" do
    it "yields items with IMDb tags" do
      items = []
      described_class.new(db_path: db_path).each_item { |item| items << item }

      expect(items.size).to eq(4)
    end

    it "extracts tconst from IMDb tag" do
      items = []
      described_class.new(db_path: db_path).each_item { |item| items << item }

      tconsts = items.map { |i| i[:tconst] }
      expect(tconsts).to contain_exactly("0000001", "0000002", "0000003", "0000004")
    end

    it "includes library name" do
      items = []
      described_class.new(db_path: db_path).each_item { |item| items << item }

      libraries = items.map { |i| i[:library_name] }.uniq
      expect(libraries).to contain_exactly("Movies", "TV Shows", "Music")
    end

    it "includes metadata type" do
      items = []
      described_class.new(db_path: db_path).each_item { |item| items << item }

      types = items.map { |i| i[:metadata_type] }.uniq
      expect(types).to contain_exactly(1, 2, 8) # movie, show, artist
    end

    it "includes title and original_title" do
      items = []
      described_class.new(db_path: db_path).each_item { |item| items << item }

      inception = items.find { |i| i[:title] == "Inception" }
      expect(inception[:original_title]).to eq("Inception Original")

      matrix = items.find { |i| i[:title] == "The Matrix" }
      expect(matrix[:original_title]).to be_nil
    end

    it "includes year" do
      items = []
      described_class.new(db_path: db_path).each_item { |item| items << item }

      matrix = items.find { |i| i[:title] == "The Matrix" }
      expect(matrix[:year]).to eq(1999)
    end

    it "includes collections" do
      items = []
      described_class.new(db_path: db_path).each_item { |item| items << item }

      matrix = items.find { |i| i[:title] == "The Matrix" }
      expect(matrix[:collections]).to eq("Sci-Fi Classics")
    end

    it "ignores items without IMDb tags" do
      items = []
      described_class.new(db_path: db_path).each_item { |item| items << item }

      titles = items.map { |i| i[:title] }
      expect(titles).not_to include("No IMDb Tag Movie")
    end

    it "requires a block" do
      reader = described_class.new(db_path: db_path)
      expect { reader.each_item }.to raise_error(ArgumentError, "Block required")
    end

    it "raises error if database not found" do
      reader = described_class.new(db_path: "/nonexistent/path.db")
      expect { reader.each_item { |_| } }.to raise_error(/Plex database not found/)
    end
  end

  describe "#items" do
    it "returns all items as an array" do
      items = described_class.new(db_path: db_path).items

      expect(items).to be_an(Array)
      expect(items.size).to eq(4)
    end
  end

  describe "#libraries" do
    it "returns list of library names" do
      libraries = described_class.new(db_path: db_path).libraries

      expect(libraries).to contain_exactly("Movies", "Music", "TV Shows")
    end

    it "returns sorted library names" do
      libraries = described_class.new(db_path: db_path).libraries

      expect(libraries).to eq(["Movies", "Music", "TV Shows"])
    end

    it "raises error if database not found" do
      reader = described_class.new(db_path: "/nonexistent/path.db")
      expect { reader.libraries }.to raise_error(/Plex database not found/)
    end
  end
end
