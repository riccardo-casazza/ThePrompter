FactoryBot.define do
  factory :plex_library_item do
    sequence(:tconst) { |n| "tt#{n.to_s.rjust(7, '0')}" }
    library_name { "Movies" }
    metadata_type { 1 }
    title { "Test Movie" }
    original_title { nil }
    year { 2020 }
    collections { nil }

    trait :movie do
      metadata_type { 1 }
      library_name { "Movies" }
    end

    trait :show do
      metadata_type { 2 }
      library_name { "TV Shows" }
      title { "Test TV Show" }
    end

    trait :artist do
      metadata_type { 8 }
      library_name { "Music" }
      title { "Test Artist" }
    end

    trait :with_collection do
      collections { "My Collection" }
    end

    trait :with_original_title do
      original_title { "Original Test Title" }
    end
  end
end
