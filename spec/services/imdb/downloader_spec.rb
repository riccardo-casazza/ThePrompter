require "rails_helper"

RSpec.describe Imdb::Downloader do
  let(:output_dir) { Rails.root.join("tmp", "test_imdb_data") }
  let(:downloader) { described_class.new(output_dir: output_dir) }
  let(:fixture_gz_path) { Rails.root.join("spec/fixtures/files/title.basics.sample.tsv.gz") }
  let(:fixture_content) { File.read(Rails.root.join("spec/fixtures/files/title.basics.sample.tsv")) }

  before do
    FileUtils.rm_rf(output_dir)
  end

  after do
    FileUtils.rm_rf(output_dir)
  end

  describe "#download_title_basics" do
    context "with successful download" do
      before do
        stub_request(:get, "https://datasets.imdbws.com/title.basics.tsv.gz")
          .to_return(
            status: 200,
            body: File.binread(fixture_gz_path),
            headers: { "Content-Type" => "application/gzip" }
          )
      end

      it "creates the output directory" do
        downloader.download_title_basics
        expect(Dir.exist?(output_dir)).to be(true)
      end

      it "returns the path to the extracted file" do
        result = downloader.download_title_basics
        expect(result.to_s).to end_with("title.basics.tsv")
      end

      it "extracts the gzipped content" do
        result = downloader.download_title_basics
        expect(File.read(result)).to eq(fixture_content)
      end

      it "removes the intermediate .gz file" do
        downloader.download_title_basics
        expect(File.exist?(output_dir.join("title.basics.tsv.gz"))).to be(false)
      end
    end

    context "with failed download" do
      before do
        stub_request(:get, "https://datasets.imdbws.com/title.basics.tsv.gz")
          .to_return(status: 404)
      end

      it "raises an error" do
        expect { downloader.download_title_basics }
          .to raise_error(RuntimeError, /Failed to download/)
      end
    end

    context "with server error" do
      before do
        stub_request(:get, "https://datasets.imdbws.com/title.basics.tsv.gz")
          .to_return(status: 500)
      end

      it "raises an error with status code" do
        expect { downloader.download_title_basics }
          .to raise_error(RuntimeError, /500/)
      end
    end
  end

  describe "constants" do
    it "uses correct IMDb datasets URL" do
      expect(described_class::DATASETS_BASE_URL).to eq("https://datasets.imdbws.com")
    end

    it "uses correct filename" do
      expect(described_class::TITLE_BASICS_FILE).to eq("title.basics.tsv.gz")
    end
  end
end
