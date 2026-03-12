namespace :plex do
  desc "Import library items from Plex database"
  task import: :environment do
    db_path = ENV.fetch("PLEX_DB_PATH", "/plex-db/com.plexapp.plugins.library.db")

    unless File.exist?(db_path)
      puts "Plex database not found: #{db_path}"
      puts "Set PLEX_DB_PATH environment variable or mount the database"
      exit 1
    end

    puts "Starting Plex library import from #{db_path}..."

    importer = Plex::LibraryImporter.new(db_path: db_path)

    libraries = importer.libraries
    puts "Found libraries: #{libraries.join(', ')}"

    importer.import

    count = PlexLibraryItem.count
    puts "Finished: #{count} items imported"
  end

  desc "List Plex libraries"
  task libraries: :environment do
    db_path = ENV.fetch("PLEX_DB_PATH", "/plex-db/com.plexapp.plugins.library.db")

    unless File.exist?(db_path)
      puts "Plex database not found: #{db_path}"
      exit 1
    end

    reader = Plex::DatabaseReader.new(db_path: db_path)
    libraries = reader.libraries

    puts "Plex libraries:"
    libraries.each { |lib| puts "  - #{lib}" }
  end

  desc "Show Plex import statistics"
  task stats: :environment do
    puts "Plex Library Items:"
    puts "  Total: #{PlexLibraryItem.count}"
    puts "  Movies: #{PlexLibraryItem.movies.count}"
    puts "  Shows: #{PlexLibraryItem.shows.count}"
    puts ""
    puts "By library:"
    PlexLibraryItem.group(:library_name).count.each do |lib, count|
      puts "  #{lib}: #{count}"
    end
    puts ""
    puts "By metadata type:"
    PlexLibraryItem.group(:metadata_type).count.each do |type, count|
      type_name = PlexLibraryItem::METADATA_TYPES[type] || "unknown (#{type})"
      puts "  #{type_name}: #{count}"
    end
  end
end
