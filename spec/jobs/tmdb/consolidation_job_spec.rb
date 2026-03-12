require "rails_helper"

RSpec.describe Tmdb::ConsolidationJob do
  describe "#perform" do
    before do
      create(:title_basic, tconst: "tt0000001", title_type: "movie")
      create(:title_basic, tconst: "tt0000002", title_type: "tvSeries")
    end

    it "consolidates TMDB tables" do
      described_class.new.perform

      expect(TitleMovieTmdb.count).to eq(1)
      expect(TitleTvTmdb.count).to eq(1)
    end

    it "returns consolidation statistics" do
      result = described_class.new.perform

      expect(result[:movies][:added]).to eq(1)
      expect(result[:tv_shows][:added]).to eq(1)
    end

    it "logs progress" do
      allow(Rails.logger).to receive(:info)

      described_class.new.perform

      expect(Rails.logger).to have_received(:info).with(/Starting TMDB consolidation/)
      expect(Rails.logger).to have_received(:info).with(/Movies:/)
      expect(Rails.logger).to have_received(:info).with(/TV Shows:/)
      expect(Rails.logger).to have_received(:info).with(/TMDB consolidation complete/)
    end
  end
end
