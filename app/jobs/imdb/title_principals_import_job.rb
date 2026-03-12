module Imdb
  class TitlePrincipalsImportJob
    include Sidekiq::Job
    sidekiq_options queue: :default

    def perform
      Rails.logger.info "Starting scheduled title.principals import..."

      downloader = Imdb::Downloader.new
      file_path = downloader.download_title_principals

      importer = Imdb::TitlePrincipalsImporter.new(file_path)
      result = importer.import

      Rails.logger.info "Import complete: #{result[:imported]} imported, #{result[:skipped]} skipped"

      File.delete(file_path) if File.exist?(file_path)
      Rails.logger.info "Cleaned up temporary files"

      result
    end
  end
end
