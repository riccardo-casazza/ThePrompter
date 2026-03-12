FactoryBot.define do
  factory :my_preference do
    sequence(:nconst) { |n| "nm#{n.to_s.rjust(7, '0')}" }
    primary_name { "Test Person" }
    category { "actor" }

    trait :actor do
      category { "actor" }
      primary_name { "Test Actor" }
    end

    trait :writer do
      category { "writer" }
      primary_name { "Test Writer" }
    end

    trait :director do
      category { "director" }
      primary_name { "Test Director" }
    end

    trait :composer do
      category { "composer" }
      primary_name { "Test Composer" }
    end
  end
end
