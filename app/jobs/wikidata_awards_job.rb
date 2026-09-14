class WikidataAwardsJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 3

  def perform
    Rails.logger.info "Starting Wikidata awards fetch..."

    was_empty = TitleAward.count.zero?

    fetcher = Wikidata::AwardsFetcher.new
    stats = fetcher.fetch_all

    total = stats.values.sum
    Rails.logger.info "Wikidata awards fetch complete. Stats: #{stats.inspect}"
    Rails.logger.info "Total award winners found: #{total}"

    # If this was the first run and we found awards, schedule another run
    # in 1 hour to catch any that might have been missed
    if was_empty && total > 0
      Rails.logger.info "First run completed, scheduling follow-up in 1 hour"
      WikidataAwardsJob.perform_in(1.hour)
    end
  end
end
