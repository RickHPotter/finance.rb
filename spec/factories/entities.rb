# frozen_string_literal: true

# == Schema Information
#
# Table name: entities
#
#  id          :integer          not null, primary key
#  entity_name :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :integer          not null
#
FactoryBot.define do
  factory :entity do
    entity_name { 'Nous' }
    association :user

    # VALID
    trait :different do
      entity_name { 'Moi' }
    end

    trait :random do
      entity_name { Faker::Book.unique.title }
    end
  end
end
