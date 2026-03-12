require "rails_helper"

RSpec.describe Tmdb::MovieRefresher do
  let(:api_key) { "test_api_key" }
  let(:client) { Tmdb::Client.new(api_key: api_key) }
  let(:refresher) { described_class.new(client: client, batch_size: 10) }

  before do
    # Create title_basics for join
    create(:title_basic, tconst: "tt0000001", title_type: "movie", start_year: 2020)
    create(:title_basic, tconst: "tt0000002", title_type: "movie", start_year: 2019)
  end

  describe "#refresh" do
    before do
      TitleMovieTmdb.create!(tconst: "tt0000001", last_update: nil)
      TitleMovieTmdb.create!(tconst: "tt0000002", last_update: 10.days.ago)
    end

    it "refreshes movies that need update" do
      stub_tmdb_find("tt0000001", movie_id: 123)
      stub_tmdb_find("tt0000002", movie_id: 456)
      stub_movie_release_dates(123)
      stub_movie_release_dates(456)
      stub_movie_details(123)
      stub_movie_details(456)

      stats = refresher.refresh

      expect(stats[:updated]).to eq(2)
      expect(stats[:errors]).to eq(0)
    end

    it "marks movies as not found when TMDB returns no results" do
      stub_tmdb_find("tt0000001", movie_id: nil)
      stub_tmdb_find("tt0000002", movie_id: nil)

      stats = refresher.refresh

      expect(stats[:not_found]).to eq(2)
      expect(TitleMovieTmdb.find_by(tconst: "tt0000001").last_update).not_to be_nil
    end

    it "extracts home release date correctly" do
      stub_tmdb_find("tt0000001", movie_id: 123)
      stub_request(:get, "https://api.themoviedb.org/3/movie/123/release_dates")
        .with(query: hash_including(api_key: api_key))
        .to_return(
          status: 200,
          body: {
            results: [
              {
                iso_3166_1: "US",
                release_dates: [
                  { type: 4, release_date: "2024-03-15T00:00:00.000Z" },
                  { type: 5, release_date: "2024-02-01T00:00:00.000Z" }
                ]
              }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      stub_movie_details(123)

      # Only refresh the first movie
      TitleMovieTmdb.find_by(tconst: "tt0000002").update!(last_update: Time.current)
      refresher.refresh

      movie = TitleMovieTmdb.find_by(tconst: "tt0000001")
      expect(movie.home_air_date).to eq(Date.new(2024, 2, 1)) # Earliest date
    end

    it "extracts theater release dates for FR and IT" do
      stub_tmdb_find("tt0000001", movie_id: 123)
      stub_request(:get, "https://api.themoviedb.org/3/movie/123/release_dates")
        .with(query: hash_including(api_key: api_key))
        .to_return(
          status: 200,
          body: {
            results: [
              {
                iso_3166_1: "FR",
                release_dates: [
                  { type: 3, release_date: "2024-01-20T00:00:00.000Z" }
                ]
              },
              {
                iso_3166_1: "IT",
                release_dates: [
                  { type: 2, release_date: "2024-01-25T00:00:00.000Z" }
                ]
              }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      stub_movie_details(123)

      TitleMovieTmdb.find_by(tconst: "tt0000002").update!(last_update: Time.current)
      refresher.refresh

      movie = TitleMovieTmdb.find_by(tconst: "tt0000001")
      expect(movie.theater_air_date_fr).to eq(Date.new(2024, 1, 20))
      expect(movie.theater_air_date_it).to eq(Date.new(2024, 1, 25))
    end

    it "extracts languages correctly" do
      stub_tmdb_find("tt0000001", movie_id: 123)
      stub_movie_release_dates(123)
      stub_request(:get, "https://api.themoviedb.org/3/movie/123")
        .with(query: hash_including(api_key: api_key))
        .to_return(
          status: 200,
          body: {
            id: 123,
            spoken_languages: [
              { iso_639_1: "FR" },
              { iso_639_1: "EN" },
              { iso_639_1: "IT" }
            ],
            original_language: "en"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      TitleMovieTmdb.find_by(tconst: "tt0000002").update!(last_update: Time.current)
      refresher.refresh

      movie = TitleMovieTmdb.find_by(tconst: "tt0000001")
      expect(movie.languages).to eq("en, fr, it") # Sorted, lowercase
    end
  end

  private

  def stub_tmdb_find(imdb_id, movie_id:)
    movie_results = movie_id ? [{ "id" => movie_id }] : []
    stub_request(:get, "https://api.themoviedb.org/3/find/#{imdb_id}")
      .with(query: hash_including(api_key: api_key))
      .to_return(
        status: 200,
        body: { movie_results: movie_results, tv_results: [] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_movie_release_dates(tmdb_id)
    stub_request(:get, "https://api.themoviedb.org/3/movie/#{tmdb_id}/release_dates")
      .with(query: hash_including(api_key: api_key))
      .to_return(
        status: 200,
        body: { results: [] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_movie_details(tmdb_id)
    stub_request(:get, "https://api.themoviedb.org/3/movie/#{tmdb_id}")
      .with(query: hash_including(api_key: api_key))
      .to_return(
        status: 200,
        body: { id: tmdb_id, spoken_languages: [], original_language: "en" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end
