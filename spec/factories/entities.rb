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
    entity_name { 'Moi' }

    # VALID
    trait :different do
      entity_name { 'Nous' }
    end

    trait :random do
      entity_name do
        [
          Faker::GreekPhilosophers.unique.name, Faker::BossaNova.unique.artist, Faker::DcComics.unique.villain
        ].sample
      end
    end
  end
end
