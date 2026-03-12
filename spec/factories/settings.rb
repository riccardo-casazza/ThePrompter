FactoryBot.define do
  factory :setting do
    sequence(:key) { |n| "setting_#{n}" }
    value { "test_value" }

    trait :title_basics_importing do
      key { "#{Setting::IMPORT_PREFIX}title_basics" }
      value { "true" }
    end

    trait :title_principals_importing do
      key { "#{Setting::IMPORT_PREFIX}title_principals" }
      value { "true" }
    end
  end
end
