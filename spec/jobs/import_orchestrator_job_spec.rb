require "rails_helper"

RSpec.describe ImportOrchestratorJob do
  describe "#perform" do
    it "creates a batch for phase 1 jobs" do
      batch_double = instance_double(Sidekiq::Batch)
      allow(Sidekiq::Batch).to receive(:new).and_return(batch_double)
      allow(batch_double).to receive(:description=)
      allow(batch_double).to receive(:on)
      allow(batch_double).to receive(:bid).and_return("test-bid")
      allow(batch_double).to receive(:jobs).and_yield

      expect(Imdb::TitleBasicsImportJob).to receive(:perform_async)
      expect(Imdb::TitlePrincipalsImportJob).to receive(:perform_async)

      described_class.new.perform
    end

    it "sets up phase 1 success callback" do
      batch_double = instance_double(Sidekiq::Batch)
      allow(Sidekiq::Batch).to receive(:new).and_return(batch_double)
      allow(batch_double).to receive(:description=)
      allow(batch_double).to receive(:bid).and_return("test-bid")
      allow(batch_double).to receive(:jobs)

      expect(batch_double).to receive(:on).with(:success, "ImportOrchestratorJob::Callbacks#phase1_complete")

      described_class.new.perform
    end
  end

  describe ImportOrchestratorJob::Callbacks do
    describe "#phase1_complete" do
      it "starts phase 2 batch with title_ratings" do
        batch_double = instance_double(Sidekiq::Batch)
        allow(Sidekiq::Batch).to receive(:new).and_return(batch_double)
        allow(batch_double).to receive(:description=)
        allow(batch_double).to receive(:on)
        allow(batch_double).to receive(:bid).and_return("test-bid")
        allow(batch_double).to receive(:jobs).and_yield

        expect(Imdb::TitleRatingsImportJob).to receive(:perform_async)

        described_class.new.phase1_complete(nil, {})
      end

      it "sets up phase 2 success callback" do
        batch_double = instance_double(Sidekiq::Batch)
        allow(Sidekiq::Batch).to receive(:new).and_return(batch_double)
        allow(batch_double).to receive(:description=)
        allow(batch_double).to receive(:bid).and_return("test-bid")
        allow(batch_double).to receive(:jobs)

        expect(batch_double).to receive(:on).with(:success, "ImportOrchestratorJob::Callbacks#phase2_complete")

        described_class.new.phase1_complete(nil, {})
      end
    end

    describe "#phase2_complete" do
      it "starts phase 3 batch with tmdb consolidation" do
        batch_double = instance_double(Sidekiq::Batch)
        allow(Sidekiq::Batch).to receive(:new).and_return(batch_double)
        allow(batch_double).to receive(:description=)
        allow(batch_double).to receive(:on)
        allow(batch_double).to receive(:bid).and_return("test-bid")
        allow(batch_double).to receive(:jobs).and_yield

        expect(Tmdb::ConsolidationJob).to receive(:perform_async)

        described_class.new.phase2_complete(nil, {})
      end

      it "sets up phase 3 success callback" do
        batch_double = instance_double(Sidekiq::Batch)
        allow(Sidekiq::Batch).to receive(:new).and_return(batch_double)
        allow(batch_double).to receive(:description=)
        allow(batch_double).to receive(:bid).and_return("test-bid")
        allow(batch_double).to receive(:jobs)

        expect(batch_double).to receive(:on).with(:success, "ImportOrchestratorJob::Callbacks#phase3_complete")

        described_class.new.phase2_complete(nil, {})
      end
    end

    describe "#phase3_complete" do
      it "logs completion" do
        expect(Rails.logger).to receive(:info).with("All import phases complete!")

        described_class.new.phase3_complete(nil, {})
      end
    end
  end
end
