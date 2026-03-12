namespace :imdb do
  desc "Download and import title.basics from IMDb datasets"
  task import_title_basics: :environment do
    puts "Starting title.basics download and import..."

    # Download
    downloader = Imdb::Downloader.new
    file_path = downloader.download_title_basics

    # Import
    importer = Imdb::TitleBasicsImporter.new(file_path)
    result = importer.import

    puts "Finished: #{result[:imported]} records imported, #{result[:skipped]} skipped"

    # Cleanup
    File.delete(file_path) if File.exist?(file_path)
    puts "Cleaned up temporary files"
  end

  desc "Download title.basics file only (no import)"
  task download_title_basics: :environment do
    downloader = Imdb::Downloader.new
    file_path = downloader.download_title_basics
    puts "Downloaded to: #{file_path}"
  end

  desc "Import title.basics from existing file"
  task :import_title_basics_from_file, [:file_path] => :environment do |_t, args|
    unless args[:file_path]
      puts "Usage: rake imdb:import_title_basics_from_file[/path/to/title.basics.tsv]"
      exit 1
    end

    unless File.exist?(args[:file_path])
      puts "File not found: #{args[:file_path]}"
      exit 1
    end

    importer = Imdb::TitleBasicsImporter.new(args[:file_path], truncate: true)
    result = importer.import

    puts "Finished: #{result[:imported]} records imported, #{result[:skipped]} skipped"
  end

  desc "Download and import title.principals from IMDb datasets"
  task import_title_principals: :environment do
    puts "Starting title.principals download and import..."

    downloader = Imdb::Downloader.new
    file_path = downloader.download_title_principals

    importer = Imdb::TitlePrincipalsImporter.new(file_path)
    result = importer.import

    puts "Finished: #{result[:imported]} records imported, #{result[:skipped]} skipped"

    File.delete(file_path) if File.exist?(file_path)
    puts "Cleaned up temporary files"
  end

  desc "Download and import title.ratings from IMDb datasets"
  task import_title_ratings: :environment do
    puts "Starting title.ratings download and import..."

    downloader = Imdb::Downloader.new
    file_path = downloader.download_title_ratings

    importer = Imdb::TitleRatingsImporter.new(file_path)
    result = importer.import

    puts "Finished: #{result[:imported]} records imported, #{result[:skipped]} skipped"

    File.delete(file_path) if File.exist?(file_path)
    puts "Cleaned up temporary files"
  end

  desc "Download and import all IMDb datasets (synchronous)"
  task import_all: :environment do
    Rake::Task["imdb:import_title_basics"].invoke
    Rake::Task["imdb:import_title_principals"].invoke
    Rake::Task["imdb:import_title_ratings"].invoke
  end

  desc "Enqueue full import orchestration (async via Sidekiq batches)"
  task orchestrate: :environment do
    puts "Enqueuing import orchestration job..."
    ImportOrchestratorJob.perform_async
    puts "Job enqueued. Monitor progress in Sidekiq dashboard."
  end
end
