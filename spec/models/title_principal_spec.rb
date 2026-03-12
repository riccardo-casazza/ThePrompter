require "rails_helper"

RSpec.describe TitlePrincipal do
  describe "validations" do
    it "is valid with valid attributes" do
      principal = build(:title_principal)
      expect(principal).to be_valid
    end

    it "requires tconst" do
      principal = build(:title_principal, tconst: nil)
      expect(principal).not_to be_valid
      expect(principal.errors[:tconst]).to include("can't be blank")
    end

    it "requires ordering" do
      principal = build(:title_principal, ordering: nil)
      expect(principal).not_to be_valid
      expect(principal.errors[:ordering]).to include("can't be blank")
    end

    it "requires nconst" do
      principal = build(:title_principal, nconst: nil)
      expect(principal).not_to be_valid
      expect(principal.errors[:nconst]).to include("can't be blank")
    end

    it "requires category" do
      principal = build(:title_principal, category: nil)
      expect(principal).not_to be_valid
      expect(principal.errors[:category]).to include("can't be blank")
    end
  end

  describe "scopes" do
    before do
      create(:title_principal, tconst: "tt0000001", ordering: 1, category: "actor")
      create(:title_principal, tconst: "tt0000001", ordering: 2, category: "director")
      create(:title_principal, tconst: "tt0000001", ordering: 3, category: "writer")
      create(:title_principal, tconst: "tt0000001", ordering: 4, category: "composer")
      create(:title_principal, tconst: "tt0000002", ordering: 1, category: "actor")
    end

    describe ".actors" do
      it "returns only actors" do
        expect(described_class.actors.count).to eq(2)
        expect(described_class.actors.pluck(:category).uniq).to eq(["actor"])
      end
    end

    describe ".directors" do
      it "returns only directors" do
        expect(described_class.directors.count).to eq(1)
      end
    end

    describe ".writers" do
      it "returns only writers" do
        expect(described_class.writers.count).to eq(1)
      end
    end

    describe ".composers" do
      it "returns only composers" do
        expect(described_class.composers.count).to eq(1)
      end
    end
  end

  describe "associations" do
    it "belongs to title_basic" do
      title = create(:title_basic, tconst: "tt1234567")
      principal = create(:title_principal, tconst: "tt1234567", ordering: 1)

      expect(principal.title_basic).to eq(title)
    end
  end

  describe "INCLUDED_CATEGORIES" do
    it "includes the expected categories" do
      expect(described_class::INCLUDED_CATEGORIES).to match_array(
        %w[actor actress director writer composer]
      )
    end
  end
end
