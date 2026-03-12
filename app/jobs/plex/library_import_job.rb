module Plex
  class LibraryImportJob
    include Sidekiq::Job
    sidekiq_options queue: :default

    def perform
      Rails.logger.info "Starting Plex library import..."

      importer = Plex::LibraryImporter.create

      libraries = importer.libraries
      Rails.logger.info "Found libraries: #{libraries.join(', ')}"

      importer.import

      count = PlexLibraryItem.count
      Rails.logger.info "Plex import complete: #{count} items imported"

      { imported: count, libraries: libraries }
    end
  end
end
