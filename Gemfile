source "https://rubygems.org"

ruby "3.3.4"

gem "rails", "~> 7.1.0"
gem "pg", "~> 1.5"
gem "puma", "~> 6.0"

# Background jobs
gem "sidekiq", "~> 7.0"
gem "connection_pool", "~> 2.5.0"  # Pin to 2.x - version 3.0.2 has Ruby 3.3 bug
gem "sidekiq-cron", "~> 1.12"
gem "sidekiq-batch", "~> 0.2"

# HTTP client for downloading files
gem "httparty", "~> 0.21"

# SQLite for reading Plex database
gem "sqlite3", "~> 1.7"

# Headless browser for scraping IMDb lists
gem "ferrum", "~> 0.15"

# Progress bar for imports
gem "ruby-progressbar", "~> 1.13"

# Boot optimization
gem "bootsnap", require: false

group :development, :test do
  gem "debug", platforms: %i[mri windows]
  gem "rspec-rails", "~> 6.0"
  gem "factory_bot_rails", "~> 6.0"
  gem "webmock", "~> 3.19"
end

group :development do
  gem "rubocop", "~> 1.60", require: false
  gem "rubocop-rails", "~> 2.23", require: false
end
