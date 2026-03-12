FactoryBot.define do
  factory :title_principal do
    sequence(:tconst) { |n| "tt#{n.to_s.rjust(7, '0')}" }
    sequence(:ordering) { |n| n }
    sequence(:nconst) { |n| "nm#{n.to_s.rjust(7, '0')}" }
    category { "actor" }

    trait :director do
      category { "director" }
    end

    trait :writer do
      category { "writer" }
    end

    trait :composer do
      category { "composer" }
    end
  end
end
