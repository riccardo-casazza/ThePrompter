require "rails_helper"

RSpec.describe Setting do
  describe "validations" do
    it "requires key" do
      setting = build(:setting, key: nil)
      expect(setting).not_to be_valid
      expect(setting.errors[:key]).to include("can't be blank")
    end

    it "requires unique key" do
      create(:setting, key: "test_key")
      duplicate = build(:setting, key: "test_key")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:key]).to include("has already been taken")
    end
  end

  describe ".get" do
    it "returns value for existing key" do
      create(:setting, key: "my_key", value: "my_value")
      expect(described_class.get("my_key")).to eq("my_value")
    end

    it "returns nil for non-existing key" do
      expect(described_class.get("non_existing")).to be_nil
    end
  end

  describe ".set" do
    it "creates new setting if key does not exist" do
      expect { described_class.set("new_key", "new_value") }
        .to change(described_class, :count).by(1)
      expect(described_class.get("new_key")).to eq("new_value")
    end

    it "updates existing setting if key exists" do
      create(:setting, key: "existing_key", value: "old_value")

      expect { described_class.set("existing_key", "new_value") }
        .not_to change(described_class, :count)
      expect(described_class.get("existing_key")).to eq("new_value")
    end

    it "converts value to string" do
      described_class.set("bool_key", true)
      expect(described_class.get("bool_key")).to eq("true")
    end
  end

  describe ".import_in_progress?" do
    it "returns false when setting does not exist" do
      expect(described_class.import_in_progress?("title_basics")).to be(false)
    end

    it "returns false when set to false" do
      described_class.import_finished!("title_basics")
      expect(described_class.import_in_progress?("title_basics")).to be(false)
    end

    it "returns true when set to true" do
      described_class.import_started!("title_basics")
      expect(described_class.import_in_progress?("title_basics")).to be(true)
    end

    it "tracks tables independently" do
      described_class.import_started!("title_basics")
      described_class.import_started!("title_principals")

      expect(described_class.import_in_progress?("title_basics")).to be(true)
      expect(described_class.import_in_progress?("title_principals")).to be(true)

      described_class.import_finished!("title_basics")

      expect(described_class.import_in_progress?("title_basics")).to be(false)
      expect(described_class.import_in_progress?("title_principals")).to be(true)
    end
  end

  describe ".any_import_in_progress?" do
    it "returns false when no imports are running" do
      expect(described_class.any_import_in_progress?).to be(false)
    end

    it "returns true when at least one import is running" do
      described_class.import_started!("title_basics")
      expect(described_class.any_import_in_progress?).to be(true)
    end

    it "returns false when all imports are finished" do
      described_class.import_started!("title_basics")
      described_class.import_finished!("title_basics")
      expect(described_class.any_import_in_progress?).to be(false)
    end
  end

  describe ".imports_in_progress" do
    it "returns empty array when no imports are running" do
      expect(described_class.imports_in_progress).to eq([])
    end

    it "returns list of tables being imported" do
      described_class.import_started!("title_basics")
      described_class.import_started!("title_principals")

      expect(described_class.imports_in_progress).to match_array(%w[title_basics title_principals])
    end

    it "excludes finished imports" do
      described_class.import_started!("title_basics")
      described_class.import_started!("title_principals")
      described_class.import_finished!("title_basics")

      expect(described_class.imports_in_progress).to eq(["title_principals"])
    end
  end

  describe ".import_started!" do
    it "sets import_in_progress to true for table" do
      described_class.import_started!("title_basics")
      expect(described_class.import_in_progress?("title_basics")).to be(true)
    end
  end

  describe ".import_finished!" do
    it "sets import_in_progress to false for table" do
      described_class.import_started!("title_basics")
      described_class.import_finished!("title_basics")
      expect(described_class.import_in_progress?("title_basics")).to be(false)
    end
  end
end
