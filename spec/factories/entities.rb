# frozen_string_literal: true

# == Schema Information
#
# Table name: entities
#
#  id          :bigint           not null, primary key
#  active      :boolean          default(TRUE), not null
#  entity_name :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_entities_on_entity_name       (entity_name) UNIQUE
#  index_entities_on_user_id           (user_id)
#  index_entity_name_on_composite_key  (user_id,entity_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :entity do
    entity_name { "Nous" }
    user { custom_create(:user) }

    trait :different do
      entity_name { "Moi" }
      user { different_custom_create(:user) }
    end

    trait :random do
      sequence(:entity_name) { |n| "#{Faker::Book.title} #{Faker::Book.author} #{n}" }
      user { random_custom_create(:user) }
    end
  end
end
