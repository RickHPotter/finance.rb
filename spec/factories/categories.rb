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

    # VALID
    trait :different do
      category_name { 'Transport' }
    end

    trait :random do
      category_name { Faker::Hobby.unique.activity }
    end
  end
end
