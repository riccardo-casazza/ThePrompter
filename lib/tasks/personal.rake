namespace :personal do
  desc "Import all personal data (preferences, blacklist, ratings)"
  task import_all: :environment do
    puts "Starting personal data import..."

    importer = Imdb::PersonalDataImporter.new
    result = importer.import_all

    result.each do |type, stats|
      puts "#{type}: #{stats[:imported]} imported"
    end

    puts "Finished"
  end

  desc "Import favorite persons (actors, writers, directors)"
  task import_preferences: :environment do
    puts "Importing favorite persons..."

    importer = Imdb::PersonalDataImporter.new
    result = importer.import_preferences

    puts "Finished: #{result[:imported]} persons imported"
  end

  desc "Import blacklisted titles"
  task import_blacklist: :environment do
    puts "Importing blacklist..."

    importer = Imdb::PersonalDataImporter.new
    result = importer.import_blacklist

    puts "Finished: #{result[:imported]} titles imported"
  end

  desc "Import my ratings"
  task import_ratings: :environment do
    puts "Importing my ratings..."

    importer = Imdb::PersonalDataImporter.new
    result = importer.import_ratings

    puts "Finished: #{result[:imported]} ratings imported"
  end

  desc "Enqueue personal data import job (async via Sidekiq)"
  task :import_async, [:type] => :environment do |_t, args|
    import_type = args[:type] || "all"
    puts "Enqueuing personal data import job (type: #{import_type})..."

    Imdb::PersonalDataImportJob.perform_async(import_type: import_type)

    puts "Job enqueued. Monitor progress in Sidekiq dashboard."
  end

  desc "Show personal data statistics"
  task stats: :environment do
    puts "Personal Data Statistics:"
    puts ""
    puts "Favorite Persons:"
    puts "  Total: #{MyPreference.count}"
    puts "  Actors: #{MyPreference.actors.count}"
    puts "  Writers: #{MyPreference.writers.count}"
    puts "  Directors: #{MyPreference.directors.count}"
    puts ""
    puts "Blacklist:"
    puts "  Total: #{BlacklistedTitle.count}"
    puts ""
    puts "My Ratings:"
    puts "  Total: #{MyRating.count}"
    puts "  Highly rated (8+): #{MyRating.highly_rated.count}"
    puts "  Low rated (4-): #{MyRating.low_rated.count}"

    if MyRating.any?
      avg = MyRating.average(:rating).to_f.round(2)
      puts "  Average rating: #{avg}"
    end
  end
end
