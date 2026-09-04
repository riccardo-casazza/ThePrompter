# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ThePrompter is a Rails 7.1 application (with basic web UI) that aggregates movie/TV data from multiple sources (IMDb, TMDB, Plex) to help discover titles based on personal preferences. It uses Sidekiq for background job processing with Redis.

This project is a migration/rewrite of a previous Scala-based implementation. The original code is preserved in `legacy/PlexTools/` for reference during migration.

## Key Features

- **Title Discovery**: Browse and filter titles by ratings, genre, cast/crew preferences
- **Plex Integration**: Track what's in your library and identify candidates for deletion based on ratings
- **Personal Preferences**: Import your IMDb ratings, watchlist, and preferred actors/directors/writers
- **Automated Updates**: Daily IMDb data imports and hourly TMDB metadata refreshes

## Common Commands

### Docker Development (Recommended)

```bash
# Start all services (Rails web server + Sidekiq worker)
docker-compose up

# Run commands in Docker containers
docker-compose exec web bin/rails console
docker-compose exec web bin/rails db:migrate
docker-compose exec web bin/rspec
docker-compose exec web bundle exec rubocop

# Run a single test file or specific test
docker-compose exec web bin/rspec spec/models/title_basic_spec.rb
docker-compose exec web bin/rspec spec/models/title_basic_spec.rb:15

# Trigger manual data import
docker-compose exec web bin/rails runner "ImportOrchestratorJob.perform_async"

# View logs
docker-compose logs -f web
docker-compose logs -f sidekiq

# Stop services
docker-compose down
```

### Local Development (Without Docker)

```bash
# Run tests
bundle exec rspec

# Run a single test file
bundle exec rspec spec/models/title_basic_spec.rb

# Run a specific test by line number
bundle exec rspec spec/models/title_basic_spec.rb:15

# Lint code
bundle exec rubocop

# Auto-fix linting issues
bundle exec rubocop -a

# Database operations
bundle exec rails db:create db:migrate
bundle exec rails db:seed

# Start Sidekiq worker separately (if not using docker-compose)
bundle exec sidekiq

# Rails console
bundle exec rails console
```

## Architecture

### Data Flow

The application imports data through a phased orchestration system (`ImportOrchestratorJob`):

1. **Phase 1** (parallel): Import `title_basics` and `title_principals` from IMDb datasets
2. **Phase 2**: Import `title_ratings` (depends on title_basics)
3. **Phase 3**: TMDB consolidation (matches IMDb titles to TMDB IDs)
4. **Phase 4** (parallel): Refresh movie and TV show metadata from TMDB API

**Scheduled Jobs** (via sidekiq-cron):
- `ImportOrchestratorJob`: Runs daily at 3 AM
- `TmdbRefreshJob`: Runs hourly to refresh TMDB metadata

### Service Organization

Services are namespaced by data source under `app/services/`:
- `Imdb::` - IMDb dataset downloaders and importers, plus personal data scraping (ratings, lists)
- `Tmdb::` - TMDB API client and metadata refreshers
- `Plex::` - Plex library reading (supports both API and direct SQLite database access)

Jobs mirror this structure under `app/jobs/`.

### Key Models

- `TitleBasic` - Core title data from IMDb (primary key: `tconst`)
- `TitlePrincipal` - Cast/crew relationships
- `TitleRating` - IMDb ratings and vote counts
- `TitleMovieTmdb` / `TitleTvTmdb` - TMDB metadata
- `MyRating` / `MyPreference` / `BlacklistedTitle` - Personal data from IMDb account
- `PlexLibraryItem` - Titles from local Plex server
- `Setting` - Key-value store for app configuration

### External Dependencies

- **IMDb**: Downloads TSV datasets from `datasets.imdbws.com`, scrapes personal data using Ferrum (headless Chrome)
- **TMDB**: REST API for movie/TV metadata (requires API key)
- **Plex**: Either HTTP API (recommended) or direct SQLite database access

## Configuration

Copy `.env.example` to `.env` and configure:
- `DATABASE_URL` - PostgreSQL connection string (or use individual `DB_HOST`, `DB_USER`, etc.)
- `REDIS_URL` - Redis connection for Sidekiq
- `TMDB_API_KEY` - Required for TMDB metadata (get one at https://www.themoviedb.org/settings/api)
- `PLEX_URL` + `PLEX_TOKEN` or `PLEX_DB_PATH` - For Plex integration (choose one method)
- `IMDB_USER_ID` + cookies - For personal IMDb data scraping (optional)
