# frozen_string_literal: true

FactoryBot.define do
  factory :entity do
    entity_name { "Nous" }
    user { custom_create(:user) }

    trait :different do
      entity_name { "Moi" }
      user { different_custom_create(:user) }
    end

    trait :random do
      sequence(:entity_name) { |n| "#{Faker::Book.title} #{Faker::Book.author} #{n}".upcase }
      user { random_custom_create(:user) }
    end
  end
end

# == Schema Information
#
# Table name: entities
#
#  id                      :bigint           not null, primary key
#  active                  :boolean          default(TRUE), not null
#  avatar_name             :string           default("people/0.png"), not null
#  card_transactions_count :integer          default(0), not null
#  card_transactions_total :integer          default(0), not null
#  cash_transactions_count :integer          default(0), not null
#  cash_transactions_total :integer          default(0), not null
#  entity_name             :string           not null, indexed => [user_id]
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  user_id                 :bigint           not null, indexed, indexed => [entity_name]
#
# Indexes
#
#  index_entities_on_user_id           (user_id)
#  index_entity_name_on_composite_key  (user_id,entity_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
