namespace :tmdb do
  desc "Consolidate TMDB tables with title_basics"
  task consolidate: :environment do
    puts "Starting TMDB consolidation..."

    consolidator = Tmdb::Consolidator.new
    result = consolidator.consolidate

    puts "Movies: #{result[:movies][:added]} added, #{result[:movies][:removed]} removed"
    puts "TV Shows: #{result[:tv_shows][:added]} added, #{result[:tv_shows][:removed]} removed"
    puts "Finished"
  end

  desc "Refresh TMDB movie data (synchronous)"
  task :refresh_movies, [:batch_size] => :environment do |_t, args|
    batch_size = (args[:batch_size] || 100).to_i
    puts "Refreshing TMDB movie data (batch_size: #{batch_size})..."

    refresher = Tmdb::MovieRefresher.new(batch_size: batch_size)
    stats = refresher.refresh

    puts "Finished: #{stats[:updated]} updated, #{stats[:not_found]} not found, #{stats[:errors]} errors"
  end

  desc "Refresh TMDB TV show data (synchronous)"
  task :refresh_tv_shows, [:batch_size] => :environment do |_t, args|
    batch_size = (args[:batch_size] || 100).to_i
    puts "Refreshing TMDB TV show data (batch_size: #{batch_size})..."

    refresher = Tmdb::TvShowRefresher.new(batch_size: batch_size)
    stats = refresher.refresh

    puts "Finished: #{stats[:updated]} updated, #{stats[:not_found]} not found, #{stats[:errors]} errors"
  end

  desc "Refresh all TMDB data (movies + TV shows, synchronous)"
  task :refresh_all, [:batch_size] => :environment do |_t, args|
    batch_size = (args[:batch_size] || 100).to_i

    Rake::Task["tmdb:refresh_movies"].invoke(batch_size)
    Rake::Task["tmdb:refresh_tv_shows"].invoke(batch_size)
  end

  desc "Enqueue TMDB refresh jobs (async via Sidekiq)"
  task :refresh_async, [:batch_size] => :environment do |_t, args|
    batch_size = (args[:batch_size] || 100).to_i
    puts "Enqueuing TMDB refresh jobs (batch_size: #{batch_size})..."

    Tmdb::MovieRefreshJob.perform_async(batch_size: batch_size)
    Tmdb::TvShowRefreshJob.perform_async(batch_size: batch_size)

    puts "Jobs enqueued. Monitor progress in Sidekiq dashboard."
  end

  desc "Show TMDB table statistics"
  task stats: :environment do
    puts "TMDB Movies:"
    puts "  Total: #{TitleMovieTmdb.count}"
    puts "  Needs update: #{TitleMovieTmdb.needs_update.count}"
    puts "  With home release: #{TitleMovieTmdb.with_home_release.count}"
    puts ""
    puts "TMDB TV Shows:"
    puts "  Total: #{TitleTvTmdb.count}"
    puts "  Needs update: #{TitleTvTmdb.needs_update.count}"
    puts "  Continuing: #{TitleTvTmdb.continuing.count}"
    puts "  Ended: #{TitleTvTmdb.ended.count}"
    puts "  With upcoming episodes: #{TitleTvTmdb.with_upcoming_episode.count}"
  end
end
