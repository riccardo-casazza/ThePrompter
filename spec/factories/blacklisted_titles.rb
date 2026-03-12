FactoryBot.define do
  factory :blacklisted_title do
    sequence(:tconst) { |n| "tt#{n.to_s.rjust(7, '0')}" }
  end
end
