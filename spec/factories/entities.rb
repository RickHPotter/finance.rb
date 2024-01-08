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
    association :user

    trait :different do
      entity_name { 'Moi' }
      association :user, :different
    end

    trait :random do
      sequence(:entity_name) { |n| "#{Faker::Book.unique.title} #{Faker::Book.unique.author} #{n}" }
      association :user, :random
    end
  end
end
