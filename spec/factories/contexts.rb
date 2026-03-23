# frozen_string_literal: true

FactoryBot.define do
  factory :context do
    user { custom_create(:user) }
    sequence(:name) { |n| n == 1 ? "Main" : "Scenario #{n}" }
    description { "Scenario planning context" }
    main { false }
    cloned_at { nil }
    archived_at { nil }

    trait :main do
      name { "Main" }
      main { true }
    end
  end
end
