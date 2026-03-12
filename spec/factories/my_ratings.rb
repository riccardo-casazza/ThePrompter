FactoryBot.define do
  factory :my_rating do
    sequence(:tconst) { |n| "tt#{n.to_s.rjust(7, '0')}" }
    rating { 7 }

    trait :highly_rated do
      rating { 9 }
    end

    trait :low_rated do
      rating { 3 }
    end
  end
end
