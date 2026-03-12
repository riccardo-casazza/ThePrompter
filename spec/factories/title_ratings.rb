FactoryBot.define do
  factory :title_rating do
    sequence(:tconst) { |n| "tt#{n.to_s.rjust(7, '0')}" }
    average_rating { 7.5 }
    num_votes { 10_000 }

    trait :highly_rated do
      average_rating { 9.0 }
      num_votes { 100_000 }
    end

    trait :poorly_rated do
      average_rating { 3.5 }
      num_votes { 500 }
    end
  end
end
