# frozen_string_literal: true

# == Schema Information
#
# Table name: categories
#
#  id            :integer          not null, primary key
#  category_name :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :integer          not null
#
FactoryBot.define do
  factory :category do
    category_name { 'Food' }
    association :user

    trait :different do
      category_name { 'Transport' }
      association :user, :different
    end

    trait :random do
      category_name { "#{Faker::Hobby.unique.activity} Level #{rand(1..10)}" }
      association :user, :random
    end
  end
end
