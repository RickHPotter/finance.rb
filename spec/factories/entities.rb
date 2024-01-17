# frozen_string_literal: true

# == Schema Information
#
# Table name: entities
#
#  id          :bigint           not null, primary key
#  entity_name :string           not null
#  user_id     :bigint           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
FactoryBot.define do
  factory :entity do
    entity_name { 'Nous' }
    user { custom_create(:user) }

    trait :different do
      entity_name { 'Moi' }
      user { different_custom_create(:user) }
    end

    trait :random do
      sequence(:entity_name) { |n| "#{Faker::Book.unique.title} #{Faker::Book.unique.author} #{n}" }
      user { random_custom_create(:user) }
    end
  end
end
