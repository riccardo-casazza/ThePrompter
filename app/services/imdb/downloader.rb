require "httparty"
require "zlib"

module Imdb
  class Downloader
    DATASETS_BASE_URL = "https://datasets.imdbws.com".freeze
    TITLE_BASICS_FILE = "title.basics.tsv.gz".freeze
    TITLE_PRINCIPALS_FILE = "title.principals.tsv.gz".freeze
    TITLE_RATINGS_FILE = "title.ratings.tsv.gz".freeze

    def initialize(output_dir: Rails.root.join("tmp", "imdb_data"))
      @output_dir = Pathname.new(output_dir)
    end

    def download_title_basics
      ensure_output_dir
      download_and_extract(TITLE_BASICS_FILE, "title.basics.tsv")
    end

    def download_title_principals
      ensure_output_dir
      download_and_extract(TITLE_PRINCIPALS_FILE, "title.principals.tsv")
    end

    def download_title_ratings
      ensure_output_dir
      download_and_extract(TITLE_RATINGS_FILE, "title.ratings.tsv")
    end

    private

    attr_reader :output_dir

    def ensure_output_dir
      FileUtils.mkdir_p(output_dir)
    end

    def download_and_extract(remote_file, output_name)
      url = "#{DATASETS_BASE_URL}/#{remote_file}"
      gz_path = output_dir.join(remote_file)
      output_path = output_dir.join(output_name)

      Rails.logger.info "Downloading #{url}..."

      # Stream directly to file to handle large downloads
      File.open(gz_path, "wb") do |file|
        HTTParty.get(url, stream_body: true) do |fragment|
          file.write(fragment)
        end
      end

      Rails.logger.info "Downloaded #{File.size(gz_path)} bytes"
      Rails.logger.info "Extracting #{gz_path} to #{output_path}..."
      extract_gzip(gz_path, output_path)

      File.delete(gz_path)
      Rails.logger.info "Download and extraction complete: #{output_path}"

      output_path
    end

    def extract_gzip(gz_path, output_path)
      Zlib::GzipReader.open(gz_path) do |gz|
        File.open(output_path, "wb") do |output|
          IO.copy_stream(gz, output)
        end
      end
    end
  end
end
