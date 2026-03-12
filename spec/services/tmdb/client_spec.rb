require "rails_helper"

RSpec.describe Tmdb::Client do
  let(:api_key) { "test_api_key" }
  let(:client) { described_class.new(api_key: api_key) }

  describe "#find_by_imdb_id" do
    it "returns movie results for a valid IMDb ID" do
      stub_request(:get, "https://api.themoviedb.org/3/find/tt0000001")
        .with(query: { api_key: api_key, external_source: "imdb_id" })
        .to_return(
          status: 200,
          body: { movie_results: [{ id: 123, title: "Test Movie" }], tv_results: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = client.find_by_imdb_id("tt0000001")

      expect(result["movie_results"].first["id"]).to eq(123)
    end

    it "returns TV results for a valid IMDb ID" do
      stub_request(:get, "https://api.themoviedb.org/3/find/tt0000002")
        .with(query: { api_key: api_key, external_source: "imdb_id" })
        .to_return(
          status: 200,
          body: { movie_results: [], tv_results: [{ id: 456, name: "Test Show" }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = client.find_by_imdb_id("tt0000002")

      expect(result["tv_results"].first["id"]).to eq(456)
    end
  end

  describe "#movie_release_dates" do
    it "returns release dates for a movie" do
      stub_request(:get, "https://api.themoviedb.org/3/movie/123/release_dates")
        .with(query: { api_key: api_key })
        .to_return(
          status: 200,
          body: {
            results: [
              {
                iso_3166_1: "US",
                release_dates: [
                  { type: 4, release_date: "2024-01-15T00:00:00.000Z" }
                ]
              }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = client.movie_release_dates("123")

      expect(result["results"].first["iso_3166_1"]).to eq("US")
    end
  end

  describe "#movie_details" do
    it "returns movie details including languages" do
      stub_request(:get, "https://api.themoviedb.org/3/movie/123")
        .with(query: { api_key: api_key })
        .to_return(
          status: 200,
          body: {
            id: 123,
            title: "Test Movie",
            spoken_languages: [{ iso_639_1: "en" }, { iso_639_1: "fr" }],
            original_language: "en"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = client.movie_details("123")

      expect(result["spoken_languages"].size).to eq(2)
    end
  end

  describe "#tv_show_details" do
    it "returns TV show details" do
      stub_request(:get, "https://api.themoviedb.org/3/tv/456")
        .with(query: { api_key: api_key })
        .to_return(
          status: 200,
          body: {
            id: 456,
            name: "Test Show",
            status: "Returning Series",
            last_air_date: "2024-01-01",
            next_episode_to_air: { air_date: "2024-02-01" },
            spoken_languages: [{ iso_639_1: "en" }]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = client.tv_show_details("456")

      expect(result["status"]).to eq("Returning Series")
      expect(result["next_episode_to_air"]["air_date"]).to eq("2024-02-01")
    end
  end

  describe "error handling" do
    it "raises UnauthorizedError on 401" do
      stub_request(:get, "https://api.themoviedb.org/3/find/tt0000001")
        .with(query: hash_including(api_key: api_key))
        .to_return(status: 401, body: "Unauthorized")

      expect { client.find_by_imdb_id("tt0000001") }
        .to raise_error(Tmdb::Client::UnauthorizedError)
    end

    it "raises NotFoundError on 404" do
      stub_request(:get, "https://api.themoviedb.org/3/movie/999")
        .with(query: hash_including(api_key: api_key))
        .to_return(status: 404, body: "Not Found")

      expect { client.movie_details("999") }
        .to raise_error(Tmdb::Client::NotFoundError)
    end

    it "raises RateLimitError on 429" do
      stub_request(:get, "https://api.themoviedb.org/3/find/tt0000001")
        .with(query: hash_including(api_key: api_key))
        .to_return(status: 429, body: "Too Many Requests")

      expect { client.find_by_imdb_id("tt0000001") }
        .to raise_error(Tmdb::Client::RateLimitError)
    end

    it "raises ApiError on server errors" do
      stub_request(:get, "https://api.themoviedb.org/3/find/tt0000001")
        .with(query: hash_including(api_key: api_key))
        .to_return(status: 500, body: "Internal Server Error")

      expect { client.find_by_imdb_id("tt0000001") }
        .to raise_error(Tmdb::Client::ApiError, /Server error/)
    end
  end
end
