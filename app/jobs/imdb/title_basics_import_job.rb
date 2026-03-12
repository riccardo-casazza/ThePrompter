module Imdb
  class TitleBasicsImportJob
    include Sidekiq::Job
    sidekiq_options queue: :default

    def perform
      Rails.logger.info "Starting scheduled title.basics import..."

      downloader = Imdb::Downloader.new
      file_path = downloader.download_title_basics

      importer = Imdb::TitleBasicsImporter.new(file_path)
      result = importer.import

      Rails.logger.info "Import complete: #{result[:imported]} imported, #{result[:skipped]} skipped"

      File.delete(file_path) if File.exist?(file_path)
      Rails.logger.info "Cleaned up temporary files"

      result
    end
  end
end
