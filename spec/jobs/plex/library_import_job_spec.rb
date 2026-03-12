require "rails_helper"

RSpec.describe Plex::LibraryImportJob do
  let(:db_path) { Rails.root.join("tmp/test_plex.db").to_s }

  before do
    PlexDatabaseHelper.create_test_database(db_path)
    PlexDatabaseHelper.populate_test_database(db_path)
  end

  after do
    File.delete(db_path) if File.exist?(db_path)
  end

  describe "#perform" do
    it "imports items from Plex database" do
      described_class.new.perform(db_path: db_path)

      expect(PlexLibraryItem.count).to eq(4)
    end

    it "returns import statistics" do
      result = described_class.new.perform(db_path: db_path)

      expect(result[:imported]).to eq(4)
      expect(result[:libraries]).to contain_exactly("Movies", "Music", "TV Shows")
    end

    it "logs import progress" do
      allow(Rails.logger).to receive(:info)

      described_class.new.perform(db_path: db_path)

      expect(Rails.logger).to have_received(:info).with(/Starting Plex library import/)
      expect(Rails.logger).to have_received(:info).with(/Found libraries/)
      expect(Rails.logger).to have_received(:info).with(/Plex import complete/)
    end

    context "with default db_path" do
      before do
        allow(ENV).to receive(:fetch).with("PLEX_DB_PATH", anything).and_return(db_path)
      end

      it "uses PLEX_DB_PATH environment variable" do
        result = described_class.new.perform

        expect(result[:imported]).to eq(4)
      end
    end
  end
end
