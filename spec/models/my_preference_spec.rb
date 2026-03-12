require "rails_helper"

RSpec.describe MyPreference do
  describe "validations" do
    it "is valid with valid attributes" do
      preference = build(:my_preference)
      expect(preference).to be_valid
    end

    it "requires nconst" do
      preference = build(:my_preference, nconst: nil)
      expect(preference).not_to be_valid
      expect(preference.errors[:nconst]).to include("can't be blank")
    end

    it "requires primary_name" do
      preference = build(:my_preference, primary_name: nil)
      expect(preference).not_to be_valid
      expect(preference.errors[:primary_name]).to include("can't be blank")
    end

    it "requires category" do
      preference = build(:my_preference, category: nil)
      expect(preference).not_to be_valid
      expect(preference.errors[:category]).to include("can't be blank")
    end

    it "validates category is one of allowed values" do
      preference = build(:my_preference, category: "invalid")
      expect(preference).not_to be_valid
      expect(preference.errors[:category]).to include("is not included in the list")
    end

    it "allows duplicate nconst with different category" do
      create(:my_preference, nconst: "nm0000001", category: "actor")
      preference = build(:my_preference, nconst: "nm0000001", category: "director")
      expect(preference).to be_valid
    end
  end

  describe "scopes" do
    before do
      create(:my_preference, :actor, nconst: "nm0000001")
      create(:my_preference, :writer, nconst: "nm0000002")
      create(:my_preference, :director, nconst: "nm0000003")
      create(:my_preference, :composer, nconst: "nm0000004")
    end

    describe ".actors" do
      it "returns only actors" do
        expect(described_class.actors.count).to eq(1)
        expect(described_class.actors.first.category).to eq("actor")
      end
    end

    describe ".writers" do
      it "returns only writers" do
        expect(described_class.writers.count).to eq(1)
        expect(described_class.writers.first.category).to eq("writer")
      end
    end

    describe ".directors" do
      it "returns only directors" do
        expect(described_class.directors.count).to eq(1)
        expect(described_class.directors.first.category).to eq("director")
      end
    end

    describe ".composers" do
      it "returns only composers" do
        expect(described_class.composers.count).to eq(1)
        expect(described_class.composers.first.category).to eq("composer")
      end
    end
  end

  describe "#imdb_url" do
    it "returns the correct IMDb URL" do
      preference = build(:my_preference, nconst: "nm1234567")
      expect(preference.imdb_url).to eq("https://www.imdb.com/name/nm1234567")
    end
  end

  describe "CATEGORIES" do
    it "includes all valid categories" do
      expect(described_class::CATEGORIES).to contain_exactly("actor", "writer", "director", "composer")
    end
  end
end
