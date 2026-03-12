# ThePrompter

A Rails application that aggregates movie and TV show data from IMDb, TMDB, and Plex to help you discover what to watch next.

## Prerequisites

- Docker and Docker Compose
- PostgreSQL 16+ (running externally)
- Redis 7+ (running externally)

## Local Development Setup

### 1. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` and set your values:

```env
# Required
DB_HOST=your-postgres-host
DB_USER=prompter
DB_PASSWORD=your-password
REDIS_URL=redis://host:6379/1
TMDB_API_KEY=your_tmdb_api_key

# Plex (at least one method)
PLEX_URL=http://your-plex-server:32400
PLEX_TOKEN=your_plex_token
```

### 2. Build Docker Images

```bash
docker-compose build
```

### 3. Setup Database

```bash
docker-compose run --rm web bin/rails db:create db:migrate
```

### 4. Start Services

```bash
docker-compose up
```

This starts:
- **web** on http://localhost:3000
- **sidekiq** for background jobs

### 5. Trigger Data Import

```bash
docker-compose exec web bin/rails runner "ImportOrchestratorJob.perform_async"
```

Monitor progress:

```bash
docker-compose logs -f sidekiq
```

## Production Setup

Docker images are automatically built and published to GitHub Container Registry on every push to `main`.

### 1. Create Production Docker Compose

Create `docker-compose.prod.yml`:

```yaml
services:
  web:
    image: ghcr.io/riccardo-casazza/theprompter:main
    command: bundle exec rails server -b 0.0.0.0
    ports:
      - "3000:3000"
    env_file:
      - .env.production
    environment:
      RAILS_ENV: production
    restart: unless-stopped

  sidekiq:
    image: ghcr.io/riccardo-casazza/theprompter:main
    command: bundle exec sidekiq
    env_file:
      - .env.production
    environment:
      RAILS_ENV: production
    restart: unless-stopped
```

### 2. Configure Production Environment

Create `.env.production`:

```env
# Database
DB_HOST=your-postgres-host
DB_USER=prompter
DB_PASSWORD=your-secure-password
DB_NAME=prompter_production

# Redis
REDIS_URL=redis://your-redis-host:6379/1

# TMDB API
TMDB_API_KEY=your_tmdb_api_key

# Plex
PLEX_URL=http://your-plex-server:32400
PLEX_TOKEN=your_plex_token

# Rails
SECRET_KEY_BASE=generate-with-rails-secret
RAILS_LOG_TO_STDOUT=true
```

Generate a secret key:

```bash
docker-compose run --rm web bin/rails secret
```

### 3. Deploy

```bash
# Pull the latest image
docker-compose -f docker-compose.prod.yml pull

# Run migrations
docker-compose -f docker-compose.prod.yml run --rm web bin/rails db:migrate

# Start services
docker-compose -f docker-compose.prod.yml up -d
```

### 4. Initial Data Import

```bash
docker-compose -f docker-compose.prod.yml exec web bin/rails runner "ImportOrchestratorJob.perform_async"
```

### 5. Verify Services

```bash
# Check containers are running
docker-compose -f docker-compose.prod.yml ps

# Check logs
docker-compose -f docker-compose.prod.yml logs -f
```

### Maintenance

```bash
# View Sidekiq logs
docker-compose -f docker-compose.prod.yml logs -f sidekiq

# Restart services
docker-compose -f docker-compose.prod.yml restart

# Stop services
docker-compose -f docker-compose.prod.yml down

# Update and redeploy
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d
```

## Useful Commands

```bash
# View logs
docker-compose logs -f web
docker-compose logs -f sidekiq

# Run a one-off Ruby command
docker-compose exec web bin/rails runner "puts TitleBasic.count"

# Run tests
docker-compose exec web bin/rspec

# Stop services
docker-compose down
```
