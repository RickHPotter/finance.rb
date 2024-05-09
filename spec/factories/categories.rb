# frozen_string_literal: true

# == Schema Information
#
# Table name: categories
#
#  id            :bigint           not null, primary key
#  category_name :string           not null
#  built_in      :boolean          default(FALSE), not null
#  user_id       :bigint           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
FactoryBot.define do
  factory :category do
    category_name { "Food" }
    user { custom_create(:user) }

    trait :different do
      category_name { "Transport" }
      user { different_custom_create(:user) }
    end

    trait :random do
      sequence(:category_name) { |n| "#{Faker::Hobby.activity} #{rand(10..99)} #{n}" }
      user { random_custom_create(:user) }
    end
  end
end
