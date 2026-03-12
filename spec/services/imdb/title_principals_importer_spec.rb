require "rails_helper"

RSpec.describe Imdb::TitlePrincipalsImporter do
  let(:fixture_path) { Rails.root.join("spec/fixtures/files/title.principals.sample.tsv") }

  describe "#import" do
    subject(:result) { described_class.new(fixture_path).import }

    it "imports included categories" do
      result
      # From fixture: actor (2), actress (1), director (2), writer (2), composer (2) = 9 valid
      expect(TitlePrincipal.count).to eq(9)
    end

    it "skips excluded categories" do
      result
      # Excluded: producer, cinematographer, editor, self, production_designer = 5 skipped
      expect(result[:skipped]).to eq(5)
    end

    it "returns correct counts" do
      expect(result[:imported]).to eq(9)
      expect(result[:skipped]).to eq(5)
    end

    it "normalizes actress to actor" do
      result
      # tt0000001, ordering 2 was actress -> should be actor now
      principal = TitlePrincipal.find_by(tconst: "tt0000001", ordering: 2)
      expect(principal.category).to eq("actor")
    end

    it "correctly parses principal data" do
      result
      principal = TitlePrincipal.find_by(tconst: "tt0000001", ordering: 1)

      expect(principal).to have_attributes(
        tconst: "tt0000001",
        ordering: 1,
        nconst: "nm0000001",
        category: "actor"
      )
    end

    it "imports directors" do
      result
      directors = TitlePrincipal.directors
      expect(directors.count).to eq(2)
    end

    it "imports writers" do
      result
      writers = TitlePrincipal.writers
      expect(writers.count).to eq(2)
    end

    it "imports composers" do
      result
      composers = TitlePrincipal.composers
      expect(composers.count).to eq(2)
    end

    it "sets timestamps" do
      freeze_time do
        result
        principal = TitlePrincipal.first
        expect(principal.created_at).to eq(Time.current)
        expect(principal.updated_at).to eq(Time.current)
      end
    end

    context "with truncate: true (default)" do
      before do
        create(:title_principal, tconst: "tt9999999", ordering: 1)
      end

      it "removes existing records before import" do
        result
        expect(TitlePrincipal.find_by(tconst: "tt9999999")).to be_nil
      end
    end

    context "with truncate: false" do
      subject(:result) { described_class.new(fixture_path, truncate: false).import }

      before do
        create(:title_principal, tconst: "tt9999999", ordering: 1)
      end

      it "preserves existing records" do
        result
        expect(TitlePrincipal.find_by(tconst: "tt9999999")).to be_present
        expect(TitlePrincipal.count).to eq(10) # 9 imported + 1 existing
      end
    end

    describe "import flag management" do
      it "sets import_in_progress at start" do
        allow(Setting).to receive(:import_started!)
        allow(Setting).to receive(:import_finished!)

        result

        expect(Setting).to have_received(:import_started!).with("title_principals").ordered
        expect(Setting).to have_received(:import_finished!).with("title_principals").ordered
      end

      it "clears import_in_progress even on error" do
        allow(File).to receive(:foreach).and_raise(StandardError, "File error")

        expect { described_class.new(fixture_path).import }.to raise_error(StandardError)
        expect(Setting.import_in_progress?("title_principals")).to be(false)
      end
    end
  end

  describe "INCLUDED_CATEGORIES" do
    it "includes actor and actress" do
      expect(described_class::INCLUDED_CATEGORIES).to include("actor", "actress")
    end

    it "includes director" do
      expect(described_class::INCLUDED_CATEGORIES).to include("director")
    end

    it "includes writer" do
      expect(described_class::INCLUDED_CATEGORIES).to include("writer")
    end

    it "includes composer" do
      expect(described_class::INCLUDED_CATEGORIES).to include("composer")
    end

    it "does not include producer" do
      expect(described_class::INCLUDED_CATEGORIES).not_to include("producer")
    end
  end
end
