FactoryBot.define do
  factory :title_basic do
    sequence(:tconst) { |n| "tt#{n.to_s.rjust(7, '0')}" }
    title_type { "movie" }
    original_title { "Test Movie" }
    start_year { 2020 }
    runtime_minutes { 120 }
    genres { "Drama,Thriller" }
    url { "https://www.imdb.com/title/#{tconst}" }

    trait :tv_series do
      title_type { "tvSeries" }
      original_title { "Test TV Series" }
    end

    trait :tv_mini_series do
      title_type { "tvMiniSeries" }
      original_title { "Test Mini Series" }
    end

    trait :short do
      title_type { "short" }
      original_title { "Test Short" }
      runtime_minutes { 15 }
    end
  end
end
