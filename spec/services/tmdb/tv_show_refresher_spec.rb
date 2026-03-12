require "rails_helper"

RSpec.describe Tmdb::TvShowRefresher do
  let(:api_key) { "test_api_key" }
  let(:client) { Tmdb::Client.new(api_key: api_key) }
  let(:refresher) { described_class.new(client: client, batch_size: 10) }

  before do
    # Create title_basics for join
    create(:title_basic, tconst: "tt0000001", title_type: "tvSeries", start_year: 2020)
    create(:title_basic, tconst: "tt0000002", title_type: "tvSeries", start_year: 2019)
  end

  describe "#refresh" do
    before do
      TitleTvTmdb.create!(tconst: "tt0000001", last_update: nil)
      TitleTvTmdb.create!(tconst: "tt0000002", last_update: 10.days.ago)
    end

    it "refreshes TV shows that need update" do
      stub_tmdb_find("tt0000001", tv_id: 123)
      stub_tmdb_find("tt0000002", tv_id: 456)
      stub_tv_details(123)
      stub_tv_details(456)

      stats = refresher.refresh

      expect(stats[:updated]).to eq(2)
      expect(stats[:errors]).to eq(0)
    end

    it "marks TV shows as not found when TMDB returns no results" do
      stub_tmdb_find("tt0000001", tv_id: nil)
      stub_tmdb_find("tt0000002", tv_id: nil)

      stats = refresher.refresh

      expect(stats[:not_found]).to eq(2)
      expect(TitleTvTmdb.find_by(tconst: "tt0000001").last_update).not_to be_nil
    end

    it "extracts last_air_date correctly" do
      stub_tmdb_find("tt0000001", tv_id: 123)
      stub_request(:get, "https://api.themoviedb.org/3/tv/123")
        .with(query: hash_including(api_key: api_key))
        .to_return(
          status: 200,
          body: {
            id: 123,
            last_air_date: "2024-01-15",
            status: "Returning Series",
            spoken_languages: []
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      TitleTvTmdb.find_by(tconst: "tt0000002").update!(last_update: Time.current)
      refresher.refresh

      tv_show = TitleTvTmdb.find_by(tconst: "tt0000001")
      expect(tv_show.last_air_date).to eq(Date.new(2024, 1, 15))
    end

    it "extracts next_air_date from next_episode_to_air" do
      stub_tmdb_find("tt0000001", tv_id: 123)
      stub_request(:get, "https://api.themoviedb.org/3/tv/123")
        .with(query: hash_including(api_key: api_key))
        .to_return(
          status: 200,
          body: {
            id: 123,
            last_air_date: "2024-01-15",
            next_episode_to_air: { air_date: "2024-02-01" },
            status: "Returning Series",
            spoken_languages: []
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      TitleTvTmdb.find_by(tconst: "tt0000002").update!(last_update: Time.current)
      refresher.refresh

      tv_show = TitleTvTmdb.find_by(tconst: "tt0000001")
      expect(tv_show.next_air_date).to eq(Date.new(2024, 2, 1))
    end

    it "sets continuing to true for running shows" do
      stub_tmdb_find("tt0000001", tv_id: 123)
      stub_request(:get, "https://api.themoviedb.org/3/tv/123")
        .with(query: hash_including(api_key: api_key))
        .to_return(
          status: 200,
          body: {
            id: 123,
            status: "Returning Series",
            spoken_languages: []
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      TitleTvTmdb.find_by(tconst: "tt0000002").update!(last_update: Time.current)
      refresher.refresh

      tv_show = TitleTvTmdb.find_by(tconst: "tt0000001")
      expect(tv_show.continuing).to be(true)
    end

    it "sets continuing to false for ended shows" do
      stub_tmdb_find("tt0000001", tv_id: 123)
      stub_request(:get, "https://api.themoviedb.org/3/tv/123")
        .with(query: hash_including(api_key: api_key))
        .to_return(
          status: 200,
          body: {
            id: 123,
            status: "Ended",
            spoken_languages: []
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      TitleTvTmdb.find_by(tconst: "tt0000002").update!(last_update: Time.current)
      refresher.refresh

      tv_show = TitleTvTmdb.find_by(tconst: "tt0000001")
      expect(tv_show.continuing).to be(false)
    end

    it "sets continuing to false for canceled shows" do
      stub_tmdb_find("tt0000001", tv_id: 123)
      stub_request(:get, "https://api.themoviedb.org/3/tv/123")
        .with(query: hash_including(api_key: api_key))
        .to_return(
          status: 200,
          body: {
            id: 123,
            status: "Canceled",
            spoken_languages: []
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      TitleTvTmdb.find_by(tconst: "tt0000002").update!(last_update: Time.current)
      refresher.refresh

      tv_show = TitleTvTmdb.find_by(tconst: "tt0000001")
      expect(tv_show.continuing).to be(false)
    end

    it "extracts languages correctly" do
      stub_tmdb_find("tt0000001", tv_id: 123)
      stub_request(:get, "https://api.themoviedb.org/3/tv/123")
        .with(query: hash_including(api_key: api_key))
        .to_return(
          status: 200,
          body: {
            id: 123,
            status: "Returning Series",
            spoken_languages: [
              { iso_639_1: "EN" },
              { iso_639_1: "ES" }
            ],
            original_language: "en"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      TitleTvTmdb.find_by(tconst: "tt0000002").update!(last_update: Time.current)
      refresher.refresh

      tv_show = TitleTvTmdb.find_by(tconst: "tt0000001")
      expect(tv_show.languages).to eq("en, es")
    end
  end

  private

  def stub_tmdb_find(imdb_id, tv_id:)
    tv_results = tv_id ? [{ "id" => tv_id }] : []
    stub_request(:get, "https://api.themoviedb.org/3/find/#{imdb_id}")
      .with(query: hash_including(api_key: api_key))
      .to_return(
        status: 200,
        body: { movie_results: [], tv_results: tv_results }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_tv_details(tmdb_id)
    stub_request(:get, "https://api.themoviedb.org/3/tv/#{tmdb_id}")
      .with(query: hash_including(api_key: api_key))
      .to_return(
        status: 200,
        body: {
          id: tmdb_id,
          status: "Returning Series",
          spoken_languages: [],
          original_language: "en"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end
